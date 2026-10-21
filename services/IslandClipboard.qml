pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var entries: []
    property string error
    property int viewers
    readonly property bool watching: viewers > 0
    readonly property bool busy: listProcess.running || actionProcess.running
    readonly property string helper: Quickshell.shellPath("modules/dashboard/helpers/clipboard.py")
    signal copied
    function refresh(): void {
        if (!busy) listProcess.running = true;
    }
    function act(action: string, id: string): void {
        if (busy || !/^[0-9]+$/.test(id)) return;
        error = "";
        actionProcess.command = ["python3", helper, action, id];
        actionProcess.running = true;
    }
    function acceptResult(text: string): var {
        try {
            const result = JSON.parse(text);
            error = result.error || "";
            return result;
        } catch (_) { error = qsTr("Unable to read clipboard history"); return {}; }
    }
    Process {
        id: listProcess
        command: ["python3", root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = root.acceptResult(text);
                if (result.entries) root.entries = result.entries;
            }
        }
    }
    Process {
        id: actionProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const result = root.acceptResult(text);
                if (result.ok && actionProcess.command[2] === "copy") root.copied();
            }
        }
        onExited: refreshDelay.restart()
    }
    Timer { id: refreshDelay; interval: 100; onTriggered: root.refresh() }
    Timer { interval: 1500; repeat: true; running: root.watching; onTriggered: root.refresh() }
}
