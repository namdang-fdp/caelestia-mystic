pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Snapshot of system and per-app memory/CPU for the left-edge resources drawer.
// Nothing runs unless something shows the drawer (viewers > 0).
Singleton {
    id: root

    readonly property string helper: Quickshell.shellPath("modules/dashboard/helpers/proc_top.py")

    // The drawer content raises this while visible and lowers it when it goes away.
    property int viewers
    property var system: ({ total_kb: 0, used_kb: 0, swap_total_kb: 0, swap_used_kb: 0, cpu_percent: 0 })
    property var groups: []
    property var claude: []
    property bool ready

    function refresh(): void {
        if (!process.running) process.running = true;
    }

    Process {
        id: process
        command: ["python3", "-I", root.helper]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.system = data.system;
                    root.groups = data.groups;
                    root.claude = data.claude;
                    root.ready = true;
                } catch (_) {}
            }
        }
    }

    // The helper samples for about 0.3 s, so a slower tick would only add lag.
    Timer {
        running: root.viewers > 0
        repeat: true
        triggeredOnStart: true
        interval: 2000
        onTriggered: root.refresh()
    }
}
