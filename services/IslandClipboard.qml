pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import "../modules/dashboard/helpers/ClipboardLogic.js" as Logic

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
    // Which app each copy came from, kept beside cliphist.
    property var meta: ({})
    readonly property var items: entries.map(e => Object.assign({}, e, { app: meta[e.id]?.app ?? "" }))
    readonly property bool paused: adapter.paused
    readonly property int retentionHours: adapter.retention
    // Copy Stack: ids in the order they were copied while the mode is on.
    property bool stackMode
    property var stack: []
    readonly property string metaHelper: Quickshell.shellPath("modules/dashboard/helpers/clipboard_meta.py")
    function setPaused(on: bool): void { adapter.paused = on; }
    function cycleRetention(): void { adapter.retention = Logic.nextRetention(adapter.retention); prune(); }
    // Deletes every recent entry; pinned items are separate saved copies and stay.
    function wipe(): void {
        if (metaProcess.running) return;
        stack = [];
        metaProcess.pending = "wipe";
        metaProcess.command = ["python3", "-I", metaHelper, "wipe"];
        metaProcess.running = true;
    }
    function setStackMode(on: bool): void { stackMode = on; if (!on) stack = []; }
    function clearStack(): void { stack = []; }
    function nextFromStack(): void {
        const result = Logic.popStack(stack);
        if (!result.next) return;
        stack = result.rest;
        act("copy", result.next);
    }
    function prune(): void {
        if (adapter.retention > 0 && !metaProcess.running) { metaProcess.pending = "prune"; metaProcess.command = ["python3", "-I", metaHelper, "prune", String(adapter.retention)]; metaProcess.running = true; }
    }
    // Called when the system clipboard changes (IslandLive); waits for cliphist to store it.
    function noteCopy(app: string): void { copyApp = app; tagDelay.restart(); }
    property string copyApp
    Timer {
        id: tagDelay
        interval: 450
        onTriggered: {
            if (metaProcess.running) { tagDelay.restart(); return; }
            metaProcess.pending = root.paused ? "drop" : "tag";
            metaProcess.command = root.paused ? ["python3", "-I", root.metaHelper, "drop-latest"] : ["python3", "-I", root.metaHelper, "tag", root.copyApp];
            metaProcess.running = true;
        }
    }
    Process {
        id: metaProcess
        property string pending
        stdout: StdioCollector {
            onStreamFinished: {
                let result = {};
                try { result = JSON.parse(text); } catch (_) {}
                if (metaProcess.pending === "wipe") { root.entries = root.entries.filter(e => e.pinned); root.thumbs = ({}); root.lastListing = ""; }
                if (metaProcess.pending === "tag" && result.id && root.stackMode) root.stack = Logic.pushStack(root.stack, result.id);
                metaLoad.running = true;
                refreshDelay.restart();
            }
        }
    }
    Process {
        id: metaLoad
        command: ["python3", "-I", root.metaHelper, "meta"]
        stdout: StdioCollector { onStreamFinished: { try { root.meta = JSON.parse(text).meta ?? {}; } catch (_) {} } }
    }
    Timer { interval: 600000; repeat: true; running: adapter.retention > 0; triggeredOnStart: true; onTriggered: root.prune() }
    Component.onCompleted: metaLoad.running = true
    FileView {
        path: `${Paths.state}/island-clipboard-settings.json`
        atomicWrites: true
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter { id: adapter; property bool paused; property int retention }
    }
    readonly property bool busy: listProcess.running || actionProcess.running
    readonly property string helper: Quickshell.shellPath("modules/dashboard/helpers/clipboard.py")
    signal copied
    function refresh(): void {
        if (!busy) listProcess.running = true;
    }
    function act(action: string, id: string): void {
        if (busy || !/^(?:[0-9]+|p[0-9a-f]{64})$/.test(id)) return;
        error = "";
        actionProcess.command = ["python3", helper, action, id];
        actionProcess.running = true;
    }
    // Called by visible delegates only, so thumbnails are decoded lazily.
    function requestThumb(id: string): void {
        if (!/^(?:[0-9]+|p[0-9a-f]{64})$/.test(id) || id in thumbs || pendingThumbs.includes(id)) return;
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
