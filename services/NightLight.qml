pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Blue-light filter. Prefers hyprsunset (IPC through hyprctl when a daemon is
// already running, otherwise a shell-owned `hyprsunset -t`), then gammastep or
// wlsunset as shell-owned processes. State persists in the shell state dir.
Singleton {
    id: root

    readonly property int minimumTemperature: 2500
    readonly property int maximumTemperature: 6500
    property alias enabled: adapter.enabled
    property alias temperature: adapter.temperature
    property string backend: ""
    // A hyprsunset daemon the shell did not start; driven only through hyprctl IPC.
    property bool external
    property bool probed
    property bool loaded
    property string error
    property bool restarting
    property int appliedTemperature: -1
    property var queuedIpc: null
    readonly property bool available: backend !== ""

    function init(): void {} // Referencing the singleton restores the saved state.
    function toggle(): void { enabled = !enabled; }
    function setTemperature(kelvin: real): void {
        temperature = Math.round(Math.max(minimumTemperature, Math.min(maximumTemperature, kelvin)) / 100) * 100;
    }

    function daemonCommand(): list<string> {
        const k = String(temperature);
        if (backend === "hyprsunset") return ["hyprsunset", "-t", k];
        if (backend === "gammastep") return ["gammastep", "-O", k];
        // wlsunset has no one-shot mode: a full-day "night" holds the low temperature.
        return ["wlsunset", "-t", k, "-T", String(temperature + 1), "-s", "00:00", "-S", "23:59", "-d", "1"];
    }

    function ipc(args: list<string>): void {
        const command = ["hyprctl", "hyprsunset", ...args];
        if (ipcProcess.running) { queuedIpc = command; return; }
        ipcProcess.command = command;
        ipcProcess.running = true;
    }

    function sync(): void {
        if (!loaded || !probed || !available) return;
        error = "";
        if (backend === "hyprsunset" && external) {
            // Untouched while disabled at startup, so an external daemon's own schedule is kept.
            if ((enabled ? temperature : -1) === appliedTemperature) return;
            appliedTemperature = enabled ? temperature : -1;
            ipc(enabled ? ["temperature", String(temperature)] : ["identity"]);
        } else if (!enabled) {
            restarting = false;
            appliedTemperature = -1;
            daemon.running = false;
        } else if (!daemon.running) {
            appliedTemperature = temperature;
            daemon.command = daemonCommand();
            daemon.running = true;
        } else if (appliedTemperature === temperature) {
            return;
        } else if (backend === "hyprsunset") {
            appliedTemperature = temperature;
            ipc(["temperature", String(temperature)]);
        } else {
            restarting = true;
            daemon.running = false;
        }
    }

    onEnabledChanged: sync()
    onTemperatureChanged: syncDelay.restart()
    onLoadedChanged: sync()
    onProbedChanged: sync()

    Timer { id: syncDelay; interval: 250; onTriggered: root.sync() }

    Process {
        id: probe
        running: true
        command: ["which", "hyprsunset", "gammastep", "wlsunset"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").map(line => line.trim().split("/").pop());
                root.backend = ["hyprsunset", "gammastep", "wlsunset"].find(name => found.includes(name)) ?? "";
                if (root.backend === "hyprsunset") daemonProbe.running = true;
                else root.probed = true;
            }
        }
    }

    Process {
        id: daemonProbe
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => { root.external = code === 0; root.probed = true; }
    }

    Process {
        id: daemon
        stderr: StdioCollector { id: daemonErrors }
        onExited: code => {
            if (root.restarting) {
                root.restarting = false;
                if (root.enabled) { root.appliedTemperature = root.temperature; daemon.command = root.daemonCommand(); daemon.running = true; }
            } else if (root.enabled) {
                root.error = daemonErrors.text.trim().split("\n").pop() || qsTr("%1 stopped (exit code %2)").arg(root.backend).arg(code);
            }
        }
    }

    Process {
        id: ipcProcess
        onExited: code => {
            if (code !== 0) root.error = qsTr("hyprsunset did not accept the request");
            if (root.queuedIpc) {
                ipcProcess.command = root.queuedIpc;
                root.queuedIpc = null;
                ipcProcess.running = true;
            }
        }
    }

    // Rapid edits are coalesced into one atomic write (back-to-back writes can be dropped).
    Timer { id: saveDelay; interval: 300; onTriggered: stateFile.writeAdapter() }

    FileView {
        id: stateFile
        path: `${Paths.state}/night-light.json`
        atomicWrites: true
        printErrors: false
        onLoaded: root.loaded = true
        onAdapterUpdated: saveDelay.restart()
        onLoadFailed: err => {
            root.loaded = true;
            if (err === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool enabled: false
            property int temperature: 4500
        }
    }

    IpcHandler {
        target: "nightLight"
        function isEnabled(): bool { return root.enabled; }
        function toggle(): void { root.toggle(); }
        function enable(): void { root.enabled = true; }
        function disable(): void { root.enabled = false; }
        function setTemperature(kelvin: int): void { root.setTemperature(kelvin); }
    }
}
