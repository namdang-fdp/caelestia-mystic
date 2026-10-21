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
    readonly property bool busy: pauseProc.running || settle.running

    function refresh(): void { if (!checkProc.running) checkProc.running = true; }
    function start(extraArgs = []): void {
        if (running || busy) return;
        props.elapsed = 0;
        Quickshell.execDetached(["caelestia", "record", ...extraArgs]);
        settle.restart();
    }
    function stop(): void {
        if (!running || busy) return;
        // The CLI finalizes/moves the file before notifying the user.
        Quickshell.execDetached(["caelestia", "record"]);
        settle.restart();
    }
    function togglePause(): void {
        if (running && !busy) pauseProc.running = true;
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
            const wasRunning = props.running;
            props.running = code === 0;
            if (!props.running) props.paused = false;
            else if (!wasRunning) { props.elapsed = 0; props.paused = false; }
        }
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
    Timer { id: settle; interval: 1200; onTriggered: root.refresh() }
    Timer { interval: 2000; repeat: true; running: root.running; onTriggered: root.refresh() }
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
