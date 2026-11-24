pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import "../modules/dashboard/helpers/ResourceLogic.js" as Logic

// One calm notification when memory or swap stays under pressure (see ResourceLogic.alertStep:
// three hot 30 s samples in a row, then quiet for 30 minutes). Needs no open drawer.
Singleton {
    id: root

    readonly property int interval: 30000

    property bool loaded
    readonly property bool enabled: adapter.alertsOn
    function setEnabled(on: bool): void {
        if (loaded)
            adapter.alertsOn = on;
    }

    property var alertState: null
    property string pendingKind
    property real pendingFraction

    function check(): void {
        const result = Logic.alertStep(alertState, {
            ramFrac: ResourcesHistory.ramFrac,
            swapFrac: ResourcesHistory.swapFrac
        }, Date.now());
        alertState = result.state;
        if (result.fire) {
            pendingKind = result.fire;
            pendingFraction = result.fire === "ram" ? ResourcesHistory.ramFrac : ResourcesHistory.swapFrac;
            // One short run to name the biggest app, only when an alert is actually due.
            if (!topProcess.running)
                topProcess.running = true;
        }
    }

    Timer {
        interval: root.interval
        running: root.enabled && ResourcesHistory.ready
        repeat: true
        onTriggered: root.check()
    }

    Process {
        id: topProcess
        command: ["python3", "-I", Quickshell.shellPath("modules/dashboard/helpers/proc_top.py"), "--interval", "0.1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let top = "";
                try {
                    const groups = JSON.parse(text).groups;
                    top = groups.length ? groups[0].name : "";
                } catch (_) {}
                const note = Logic.alertText(root.pendingKind, root.pendingFraction, top);
                Quickshell.execDetached(["notify-send", "-a", "Island", "-i", "dialog-warning", note.title, note.body]);
            }
        }
    }

    Timer {
        id: save
        interval: 400
        onTriggered: file.writeAdapter()
    }
    FileView {
        id: file
        path: `${Paths.state}/resources.json`
        atomicWrites: true
        printErrors: false
        onAdapterUpdated: save.restart()
        onLoaded: root.loaded = true
        onLoadFailed: error => {
            root.loaded = true;
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool alertsOn: true
        }
    }
}
