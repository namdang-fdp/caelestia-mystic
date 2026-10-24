pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import "../modules/dock/helpers/DockLogic.js" as Logic

// Dock settings live in their own file because the Caelestia config schema is
// compiled into the C++ plugin and cannot be extended from QML.
Singleton {
    id: root

    readonly property alias enabled: adapter.enabled
    readonly property alias pinnedApps: adapter.pinnedApps
    readonly property alias iconSize: adapter.iconSize
    readonly property alias magnification: adapter.magnification
    readonly property alias magnify: adapter.magnify
    readonly property alias hideMode: adapter.hideMode
    readonly property alias bottomMargin: adapter.bottomMargin
    readonly property alias showRunning: adapter.showRunning
    readonly property alias currentMonitorOnly: adapter.currentMonitorOnly
    readonly property alias showIndicators: adapter.showIndicators
    readonly property alias showBadges: adapter.showBadges
    readonly property alias badgeStyle: adapter.badgeStyle
    readonly property alias showLabels: adapter.showLabels
    readonly property alias bounce: adapter.bounce
    readonly property alias showClaudeUsage: adapter.showClaudeUsage
    readonly property alias showCodexUsage: adapter.showCodexUsage
    readonly property alias usageInterval: adapter.usageInterval
    readonly property alias usageWarnings: adapter.usageWarnings

    readonly property list<string> hideModes: ["never", "smart", "always"]

    function set(key: string, value: var): void {
        adapter[key] = value;
    }

    function isPinned(id: string): bool {
        return adapter.pinnedApps.includes(id);
    }

    function pin(id: string): void {
        if (id && !isPinned(id))
            adapter.pinnedApps = [...adapter.pinnedApps, id];
    }

    function unpin(id: string): void {
        adapter.pinnedApps = adapter.pinnedApps.filter(a => a !== id);
    }

    function movePinned(id: string, offset: int): void {
        const list = [...adapter.pinnedApps];
        const from = list.indexOf(id);
        const to = from + offset;
        if (from < 0 || to < 0 || to >= list.length)
            return;
        list.splice(to, 0, list.splice(from, 1)[0]);
        adapter.pinnedApps = list;
    }

    // Moves id to index `to` among the pins in `visible`, as ordered on the dock
    function movePinnedTo(id: string, visible: list<string>, to: int): void {
        const list = Logic.reorderPinned(adapter.pinnedApps, visible, id, to);
        if (list.some((k, i) => k !== adapter.pinnedApps[i]))
            adapter.pinnedApps = list;
    }

    FileView {
        path: `${Paths.config}/dock.json`
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property bool enabled: true
            property var pinnedApps: ["zen", "kitty", "org.gnome.Nautilus", "code", "com.anthropic.Claude", "obsidian", "spotify"]
            property int iconSize: 48
            property real magnification: 1.6
            property bool magnify: true
            // never: always shown and reserves space; smart: hides when a window overlaps it;
            // always: hidden until the cursor reaches the bottom edge
            property string hideMode: "smart"
            property int bottomMargin: 8
            property bool showRunning: true
            // Only list windows on the dock's own monitor
            property bool currentMonitorOnly: false
            property bool showIndicators: true
            property bool showBadges: true
            // count: numbered pill; dot: plain dot
            property string badgeStyle: "count"
            property bool showLabels: true
            property bool bounce: true
            // AI plan usage tiles at the end of the dock
            property bool showClaudeUsage: true
            property bool showCodexUsage: true
            property int usageInterval: 5 // minutes
            property bool usageWarnings: true
        }
    }
}
