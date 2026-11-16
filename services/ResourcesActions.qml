pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/dashboard/helpers/ResourceLogic.js" as Logic

// Stopping processes from the drawer. Every Stop button is two-step (first click arms it, the
// second fires) and goes through proc_action.py, which re-checks the process before signalling.
Singleton {
    id: root

    readonly property string helper: Quickshell.shellPath("modules/dashboard/helpers/proc_action.py")
    readonly property int confirmMs: 3000

    // Which Stop button is armed (one at a time), as { key, until } or null.
    property var armed: null
    property bool busy
    // One-line result of the last stop, cleared after a few seconds.
    property string status
    property var queue: []

    signal stopped(var result)

    // True when the click was the confirming one.
    function click(key: string): bool {
        const r = Logic.confirmClick(armed, key, Date.now(), confirmMs);
        armed = r.armed;
        if (r.armed)
            disarm.restart();
        else
            disarm.stop();
        return r.fire;
    }

    function stop(pid: int, start: int): void {
        if (busy)
            return;
        busy = true;
        status = "";
        process.command = ["python3", "-I", helper, "stop", String(pid), String(start)];
        process.running = true;
    }

    // Stops several targets one after another ({ pid, start } each).
    function stopAll(targets: var): void {
        if (busy || targets.length === 0)
            return;
        queue = targets.slice(1);
        stop(targets[0].pid, targets[0].start);
    }

    Process {
        id: process
        stdout: StdioCollector {
            onStreamFinished: {
                let result;
                try {
                    result = JSON.parse(text);
                } catch (_) {
                    result = { ok: false, error: "failed" };
                }
                root.busy = false;
                root.status = result.ok ? "Stopped" : "Not stopped: " + result.error;
                root.stopped(result);
                if (root.queue.length > 0) {
                    const next = root.queue[0];
                    root.queue = root.queue.slice(1);
                    root.stop(next.pid, next.start);
                } else {
                    refreshLater.restart();
                }
            }
        }
    }

    // Give the process a moment to exit before the next listing.
    Timer {
        id: refreshLater
        interval: 600
        onTriggered: Resources.refresh()
    }
    Timer {
        id: disarm
        interval: root.confirmMs
        onTriggered: root.armed = null
    }
    Timer {
        interval: 4000
        running: root.status !== ""
        onTriggered: root.status = ""
    }
}
