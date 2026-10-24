pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root
    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    // `caelestia record` is a toggle, so every start/stop first checks the real
    // recorder state and stays busy until the requested state is observed.
    readonly property bool busy: pauseProc.running || pendingAction !== ""

    property string pendingAction // "", "start" or "stop" while a toggle is in flight
    property var pendingArgs: []
    property bool confirming // toggle sent, waiting for pidof to agree

    function refresh(): void { if (!checkProc.running) checkProc.running = true; }
    function start(extraArgs = []): void {
        if (busy) return;
        pendingArgs = extraArgs;
        beginAction("start");
    }
    function stop(): void {
        if (busy) return;
        beginAction("stop");
    }
    function togglePause(): void {
        if (running && !busy) pauseProc.running = true;
    }
    function beginAction(action: string): void {
        pendingAction = action;
        confirming = false;
        actionTimeout.restart();
        preCheckProc.running = true;
    }
    function handlePreCheck(isRunning: bool): void {
        if (!pendingAction || confirming) return;
        applyRunning(isRunning);
        // Only toggle when the real state is the opposite of the requested one;
        // otherwise a stale `running` would make Stop start a new recording.
        if ((pendingAction === "start") === isRunning) {
            finishAction();
            return;
        }
        if (pendingAction === "start") {
            props.elapsed = 0;
            Quickshell.execDetached(["caelestia", "record", ...pendingArgs]);
        } else {
            // The CLI finalizes/moves the file before notifying the user.
            Quickshell.execDetached(["caelestia", "record"]);
        }
        confirming = true;
        confirmPoll.restart();
    }
    function applyRunning(isRunning: bool): void {
        const wasRunning = props.running;
        props.running = isRunning;
        if (!isRunning) props.paused = false;
        else if (!wasRunning) { props.elapsed = 0; props.paused = false; }
    }
    function finishAction(): void {
        pendingAction = "";
        pendingArgs = [];
        confirming = false;
        confirmPoll.stop();
        actionTimeout.stop();
    }
    PersistentProperties {
        id: props
        reloadableId: "recorder"
        property bool running: false
        property bool paused: false
        property real elapsed: 0
    }
    Process {
        id: checkProc
        running: true
        command: ["pidof", "gpu-screen-recorder"]
        onExited: code => {
            root.applyRunning(code === 0);
            if (root.confirming && (root.pendingAction === "start") === props.running)
                root.finishAction();
        }
    }
    Process {
        id: preCheckProc
        command: ["pidof", "gpu-screen-recorder"]
        onExited: code => root.handlePreCheck(code === 0)
    }
    Process {
        id: pauseProc
        command: ["caelestia", "record", "-p"]
        onExited: code => {
            if (code === 0 && root.running) props.paused = !props.paused;
            root.refresh();
        }
    }
    // The recorder CLI rewrites this small file when recording starts, including
    // from Hyprland shortcuts. No process polling is needed while idle.
    FileView {
        path: `${Paths.state}/record/notifid.txt`
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); root.refresh(); }
    }
    Timer { id: confirmPoll; interval: 300; repeat: true; onTriggered: root.refresh() }
    // Give up waiting for confirmation (e.g. recorder failed to start) and resync.
    Timer {
        id: actionTimeout
        interval: 6000
        onTriggered: { root.finishAction(); root.refresh(); }
    }
    Timer { interval: 2000; repeat: true; running: root.running && !root.busy; onTriggered: root.refresh() }
    Connections {
        target: Time
        enabled: root.running && !root.paused
        function onSecondsChanged(): void { props.elapsed++; }
    }
    IpcHandler {
        target: "recorder"
        function start(): void { root.start(); }
        function stop(): void { root.stop(); }
        function pause(): void { root.togglePause(); }
        function status(): string { return JSON.stringify({ running: root.running, paused: root.paused, elapsed: root.elapsed, busy: root.busy }); }
    }
}
