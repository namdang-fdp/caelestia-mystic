pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.services

Singleton {
    id: root

    readonly property string separator: "::separator"

    // Hyprland toplevels that can be represented by an app icon
    readonly property list<HyprlandToplevel> windows: Hypr.toplevels.values.filter(t => root.classOf(t))

    // Lookups below read this so bindings re-evaluate once desktop entries load
    readonly property list<DesktopEntry> apps: DesktopEntries.applications.values

    readonly property list<string> pinnedKeys: DockConfig.pinnedApps.filter(id => apps.some(a => a.id === id))
    readonly property list<string> runningKeys: {
        const keys = [];
        for (const t of windows) {
            const key = keyFor(t);
            if (!keys.includes(key))
                keys.push(key);
        }
        return keys;
    }
    readonly property string usagePrefix: "::usage:"
    readonly property list<string> usageKeys: AiUsage.providers.map(p => usagePrefix + p.key)
    readonly property list<string> items: {
        const running = DockConfig.showRunning ? runningKeys.filter(k => !pinnedKeys.includes(k)) : [];
        const groups = [pinnedKeys, running, usageKeys].filter(g => g.length > 0);
        return groups.reduce((all, group, i) => i === 0 ? [...group] : [...all, separator + i, ...group], []);
    }

    readonly property string activeKey: Hyprland.activeToplevel ? keyFor(Hyprland.activeToplevel) : ""

    readonly property var lookupCache: apps.length >= 0 ? new Map() : null

    function classOf(toplevel: HyprlandToplevel): string {
        return toplevel?.lastIpcObject.class || toplevel?.wayland?.appId || "";
    }

    // Groups windows by desktop entry id so pinned entries and running windows share a key
    function keyFor(toplevel: HyprlandToplevel): string {
        const cls = classOf(toplevel);
        if (!cls)
            return "";
        if (!lookupCache.has(cls))
            lookupCache.set(cls, DesktopEntries.heuristicLookup(cls)?.id ?? cls);
        return lookupCache.get(cls);
    }

    function isSeparator(key: string): bool {
        return key.startsWith(separator);
    }

    function entryFor(key: string): DesktopEntry {
        if (key.startsWith("::"))
            return null;
        return apps.find(a => a.id === key) ?? (apps.length > 0 ? DesktopEntries.heuristicLookup(key) : null);
    }

    function windowsFor(key: string): list<HyprlandToplevel> {
        return windows.filter(t => keyFor(t) === key).sort((a, b) => (a.lastIpcObject.focusHistoryID ?? 0) - (b.lastIpcObject.focusHistoryID ?? 0));
    }

    function badgeCount(key: string): int {
        const entry = entryFor(key);
        const names = new Set([key, entry?.id, entry?.name, entry?.icon].filter(n => n).map(n => n.toLowerCase()));
        let count = 0;
        for (const n of Notifs.notClosed) {
            const desktopEntry = n.notification?.desktopEntry ?? "";
            if (names.has(n.appName.toLowerCase()) || (desktopEntry && names.has(desktopEntry.toLowerCase())) || (n.appIcon && names.has(n.appIcon.toLowerCase())))
                count++;
        }
        return count;
    }

    function focus(toplevel: HyprlandToplevel): void {
        if (toplevel.wayland) {
            toplevel.wayland.activate();
            return;
        }

        const address = toplevel.address.startsWith("0x") ? toplevel.address : `0x${toplevel.address}`;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:${address}" })` : `focuswindow address:${address}`);
    }

    function launch(key: string): bool {
        const entry = entryFor(key);
        if (!entry)
            return false;

        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
        return true;
    }

    // Returns true when the app was launched rather than focused
    function activate(key: string): bool {
        const wins = windowsFor(key);
        if (wins.length === 0)
            return launch(key);

        // Clicking the focused app cycles through its windows
        const activeIdx = wins.findIndex(t => t === Hyprland.activeToplevel);
        if (activeIdx >= 0)
            focus(wins[wins.length > 1 ? wins.length - 1 : 0]);
        else
            focus(wins[0]);
        return false;
    }

    function closeAll(key: string): void {
        for (const t of windowsFor(key))
            t.wayland?.close();
    }
}
