pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import "../modules/dashboard/helpers/ActivityLogic.js" as Logic

// File shelf: holds references to files dropped on the island until they are
// dragged out, opened or removed. Files are never copied or moved.
Singleton {
    id: root

    readonly property int limit: 24
    readonly property var items: adapter.items
    readonly property int count: items.length
    property bool loaded
    // Paths whose stat is in flight, so add() and the startup check never overlap.
    property var queue: []
    signal added(int count, string firstName)

    function add(paths: var): void {
        const fresh = paths.filter(p => typeof p === "string" && p.startsWith("/"));
        if (!fresh.length) return;
        queue = [...queue, ...fresh];
        if (!statProcess.running) flush();
    }
    function remove(path: string): void {
        adapter.items = items.filter(i => i.path !== path);
    }
    function clear(): void {
        adapter.items = [];
    }
    function open(path: string): void {
        Quickshell.execDetached(["xdg-open", path]);
    }
    function url(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    function flush(): void {
        if (!queue.length) return;
        statProcess.requested = queue;
        queue = [];
        statProcess.command = ["stat", "-L", "--printf", "%s\t%F\t%n\\0", "--", ...statProcess.requested];
        statProcess.running = true;
    }

    // `stat` prints "<bytes>\t<type>\t<path>\0" per file it can still reach.
    Process {
        id: statProcess
        property var requested: []
        property bool validating
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\0").filter(Boolean).map(line => {
                    const [size, type, ...rest] = line.split("\t");
                    const path = rest.join("\t");
                    return { path, name: path.slice(path.lastIndexOf("/") + 1) || path, size: Number(size), isDir: type === "directory", added: Date.now() };
                });
                if (statProcess.validating) {
                    // Startup check: keep order and timestamps, drop what disappeared.
                    const alive = new Map(found.map(i => [i.path, i]));
                    adapter.items = root.items.filter(i => alive.has(i.path)).map(i => Object.assign({}, i, { size: alive.get(i.path).size }));
                    statProcess.validating = false;
                } else if (found.length) {
                    adapter.items = Logic.shelfMerge(root.items, found, root.limit);
                    root.added(found.length, found[0].name);
                }
            }
        }
        onExited: root.flush()
    }

    // `qs -c caelestia ipc call islandShelf add /path/to/file`
    IpcHandler {
        target: "islandShelf"
        function add(path: string): void { root.add([path]); }
        function remove(path: string): void { root.remove(path); }
        function clear(): void { root.clear(); }
        function list(): string { return root.items.map(i => i.path).join("\n"); }
    }

    Timer { id: saveDelay; interval: 300; onTriggered: shelfFile.writeAdapter() }

    FileView {
        id: shelfFile
        path: `${Paths.state}/island-shelf.json`
        atomicWrites: true
        printErrors: false
        onAdapterUpdated: saveDelay.restart()
        onLoaded: {
            root.loaded = true;
            if (!root.items.length || statProcess.running) return;
            statProcess.validating = true;
            statProcess.requested = root.items.map(i => i.path);
            statProcess.command = ["stat", "-L", "--printf", "%s\t%F\t%n\\0", "--", ...statProcess.requested];
            statProcess.running = true;
        }
        onLoadFailed: err => {
            root.loaded = true;
            if (err === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property var items: []
        }
    }
}
