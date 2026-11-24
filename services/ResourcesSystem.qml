pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// GPU clock and disk numbers for the System tab. Polls only while that tab exists.
Singleton {
    id: root

    property int viewers
    property var gpu: null
    property var disk: ({ total_kb: 0, used_kb: 0, read_bps: 0, write_bps: 0 })
    property bool ready

    function refresh(): void {
        if (!process.running)
            process.running = true;
    }

    Process {
        id: process
        command: ["python3", "-I", Quickshell.shellPath("modules/dashboard/helpers/sys_stats.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.gpu = data.gpu;
                    root.disk = data.disk;
                    root.ready = true;
                } catch (_) {}
            }
        }
    }

    // The helper samples disk throughput for about 0.3 s, so a slower tick adds no lag.
    Timer {
        running: root.viewers > 0
        repeat: true
        triggeredOnStart: true
        interval: 3000
        onTriggered: root.refresh()
    }
}
