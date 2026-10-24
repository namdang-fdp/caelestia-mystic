pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var entries: []
    property string error
    property int viewers
    // id -> cached image path ("" when the entry could not be decoded as an image).
    property var thumbs: ({})
    property var pendingThumbs: []
    property string lastListing
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
    // Called by visible delegates only, so thumbnails are decoded lazily.
    function requestThumb(id: string): void {
        if (!/^[0-9]+$/.test(id) || id in thumbs || pendingThumbs.includes(id)) return;
        pendingThumbs = [...pendingThumbs, id];
        thumbDelay.restart();
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
                // Unchanged history keeps the existing model, so the list is not rebuilt every poll.
                if (text === root.lastListing && !root.error) return;
                const result = root.acceptResult(text);
                if (!result.entries) return;
                root.lastListing = text;
                root.entries = result.entries;
                const ids = new Set(result.entries.map(e => e.id));
                const kept = {};
                for (const id in root.thumbs) if (ids.has(id)) kept[id] = root.thumbs[id];
                root.thumbs = kept;
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
    Process {
        id: thumbProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text).thumbs ?? {};
                    root.thumbs = Object.assign({}, root.thumbs, result);
                } catch (_) {}
            }
        }
        onExited: {
            const requested = thumbProcess.command.slice(3);
            const missing = {};
            for (const id of requested) if (!(id in root.thumbs)) missing[id] = "";
            if (Object.keys(missing).length) root.thumbs = Object.assign({}, root.thumbs, missing);
            if (root.pendingThumbs.length) thumbDelay.restart();
        }
    }
    Timer {
        id: thumbDelay
        interval: 60
        onTriggered: {
            if (thumbProcess.running || !root.pendingThumbs.length) return;
            const batch = root.pendingThumbs.slice(0, 12);
            root.pendingThumbs = root.pendingThumbs.slice(12);
            thumbProcess.command = ["python3", root.helper, "thumbs", ...batch];
            thumbProcess.running = true;
        }
    }
    Timer { id: refreshDelay; interval: 100; onTriggered: root.refresh() }
    Timer { interval: 1500; repeat: true; running: root.watching; onTriggered: root.refresh() }
}
