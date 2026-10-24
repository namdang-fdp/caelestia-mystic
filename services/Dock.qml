pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.services
import "../modules/dock/helpers/DockLogic.js" as Logic

Singleton {
    id: root

    readonly property string separator: "::separator"

    // Hyprland toplevels that can be represented by an app icon
    readonly property list<HyprlandToplevel> windows: Hypr.toplevels.values.filter(t => root.classOf(t))

    // Lookups below read this so bindings re-evaluate once desktop entries load
    readonly property list<DesktopEntry> apps: DesktopEntries.applications.values

    readonly property list<string> pinnedKeys: DockConfig.pinnedApps.filter(id => apps.some(a => a.id === id))
    readonly property string usagePrefix: "::usage:"
    readonly property list<string> usageKeys: AiUsage.shownProviders.map(p => usagePrefix + p.key)

    readonly property string activeKey: Hypr.activeToplevel ? keyFor(Hypr.activeToplevel) : ""

    // Floating windows move and resize without an IPC event, so smart hide polls their geometry
    readonly property bool watchGeometry: DockConfig.enabled && DockConfig.hideMode === "smart" && windows.some(t => t.lastIpcObject.floating && !t.lastIpcObject.hidden && (t.workspace?.active || t.workspace?.name.startsWith("special:")))

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

    // Windows the dock on `monitor` represents
    function windowsOn(monitor: HyprlandMonitor): list<HyprlandToplevel> {
        return DockConfig.currentMonitorOnly && monitor ? windows.filter(t => t.monitor === monitor) : windows;
    }

    function itemsFor(monitor: HyprlandMonitor): list<string> {
        const running = [];
        if (DockConfig.showRunning) {
            for (const t of windowsOn(monitor)) {
                const key = keyFor(t);
                if (key && !running.includes(key) && !pinnedKeys.includes(key))
                    running.push(key);
            }
        }
        const groups = [pinnedKeys, running, usageKeys].filter(g => g.length > 0);
        return groups.reduce((all, group, i) => i === 0 ? [...group] : [...all, separator + i, ...group], []);
    }

    function isSeparator(key: string): bool {
        return key.startsWith(separator);
    }

    function entryFor(key: string): DesktopEntry {
        if (key.startsWith("::"))
            return null;
        return apps.find(a => a.id === key) ?? (apps.length > 0 ? DesktopEntries.heuristicLookup(key) : null);
    }

    function windowsFor(key: string, monitor: HyprlandMonitor): list<HyprlandToplevel> {
        return windowsOn(monitor).filter(t => keyFor(t) === key).sort((a, b) => (a.lastIpcObject.focusHistoryID ?? 0) - (b.lastIpcObject.focusHistoryID ?? 0));
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

    function selectorFor(toplevel: HyprlandToplevel): string {
        const address = toplevel?.address ?? "";
        return /^(?:0x)?[0-9a-f]+$/i.test(address) ? `address:${address.startsWith("0x") ? address : "0x" + address}` : "";
    }

    function focus(toplevel: HyprlandToplevel): void {
        if (toplevel.wayland) {
            toplevel.wayland.activate();
            return;
        }

        const selector = selectorFor(toplevel);
        if (selector)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "${selector}" })` : `focuswindow ${selector}`);
    }

    function close(toplevel: HyprlandToplevel): void {
        if (toplevel.wayland) {
            toplevel.wayland.close();
            return;
        }

        // XWayland and other windows without a foreign toplevel handle
        const selector = selectorFor(toplevel);
        if (selector)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "${selector}" })` : `closewindow ${selector}`);
    }

    function closeWindows(toplevels: list<HyprlandToplevel>): void {
        for (const t of [...toplevels])
            close(t);
    }

    function run(entry: DesktopEntry, command: list<string>): void {
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...command],
                workingDirectory: entry.workingDirectory
            });
        else
            Quickshell.execDetached({
                command: command,
                workingDirectory: entry.workingDirectory
            });
    }

    function launch(key: string): bool {
        const entry = entryFor(key);
        if (!entry)
            return false;

        if (entry.runInTerminal)
            run(entry, entry.command);
        else
            entry.execute();
        return true;
    }

    // Desktop actions such as "New Private Window"
    function runAction(key: string, action: DesktopAction): bool {
        const entry = entryFor(key);
        if (!entry || !action)
            return false;

        if (entry.runInTerminal)
            run(entry, action.command);
        else
            action.execute();
        return true;
    }

    // Opens dropped files or URLs with the app
    function openWith(key: string, urls: list<string>): bool {
        const entry = entryFor(key);
        if (!entry)
            return false;

        const commands = Logic.expandExec(entry.execString, urls, entry.name, entry.icon);
        if (commands.length === 0)
            return launch(key);
        for (const command of commands)
            run(entry, command);
        return true;
    }

    // Returns true when the app was launched rather than focused
    function activate(key: string, monitor: HyprlandMonitor): bool {
        const wins = windowsFor(key, monitor);
        if (wins.length === 0)
            return launch(key);

        // Clicking the focused app cycles through its windows
        const activeIdx = wins.findIndex(t => t === Hypr.activeToplevel);
        if (activeIdx >= 0)
            focus(wins[wins.length > 1 ? wins.length - 1 : 0]);
        else
            focus(wins[0]);
        return false;
    }

    // Scroll wheel cycling, in a stable order so repeated steps visit every window
    function cycle(toplevels: list<HyprlandToplevel>, step: int): void {
        const wins = [...toplevels].sort((a, b) => a.address.localeCompare(b.address));
        const next = Logic.cycleIndex(wins.findIndex(t => t === Hypr.activeToplevel), wins.length, step);
        if (next >= 0)
            focus(wins[next]);
    }

    Timer {
        running: root.watchGeometry
        repeat: true
        interval: 1000
        onTriggered: Hyprland.refreshToplevels()
    }
}
