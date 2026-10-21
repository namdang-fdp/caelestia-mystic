pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root
    readonly property var overviewWindows: Hypr.toplevels.values.filter(t => (t.workspace?.id > 0 || canonicalSpecialName(t.workspace?.name ?? "") !== null) && t.lastIpcObject.mapped !== false && !t.lastIpcObject.hidden)
    readonly property var windows: overviewWindows.filter(t => t.workspace?.id > 0)
    readonly property var specialWindows: overviewWindows.filter(t => canonicalSpecialName(t.workspace?.name ?? "") !== null)
    readonly property var specialNames: {
        const names = ["", "todo", "music", "communication", "sysmon"];
        for (const workspace of Hypr.workspaces.values) {
            const name = canonicalSpecialName(workspace.name ?? "");
            if (name !== null && !names.includes(name)) names.push(name);
        }
        for (const client of specialWindows) {
            const name = canonicalSpecialName(client.workspace?.name ?? "");
            if (name !== null && !names.includes(name)) names.push(name);
        }
        return names;
    }
    // Retain primitive keys while Hyprland QObjects are removed during event delivery.
    property var windowAddresses: []
    property int overviewViewers
    readonly property var workspaceIds: Hypr.workspaces.values.filter(w => w.id > 0).map(w => w.id).sort((a, b) => a - b)
    onOverviewWindowsChanged: {
        if (overviewViewers === 0) {
            windowAddresses = overviewWindows.map(addressOf);
            return;
        }
        const keys = windowAddresses.slice();
        for (const client of overviewWindows) {
            const address = addressOf(client);
            if (address && !keys.includes(address)) keys.push(address);
        }
        if (keys.length !== windowAddresses.length) windowAddresses = keys;
    }
    onOverviewViewersChanged: if (overviewViewers === 0) windowAddresses = overviewWindows.map(addressOf)
    function addressOf(client: var): string { return client?.address || client?.lastIpcObject.address || ""; }
    function windowFor(address: string): var { return overviewWindows.find(t => addressOf(t) === address) ?? null; }
    function canonicalSpecialName(fullName: string): var {
        if (!fullName.startsWith("special:")) return null;
        const name = fullName.slice(8);
        return name === "special" ? "" : name;
    }
    function fullSpecialName(name: string): string { return name === "" ? "special:special" : `special:${name}`; }
    function specialDisplayName(name: string): string { return name === "" ? qsTr("Default") : name.charAt(0).toUpperCase() + name.slice(1); }
    function visibleMonitorForSpecial(name: string): string {
        return Hypr.monitors.values.find(m => m.lastIpcObject?.specialWorkspace?.name === fullSpecialName(name))?.name ?? "";
    }
    function luaString(value: string): string {
        return '"' + value.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }
    function validSpecialName(name: string): bool {
        return specialNames.includes(name) && !/[\x00-\x1f\x7f]/.test(name) && (Hypr.usingLua || !name.includes(","));
    }
    function selectorFor(address: string): string {
        return /^(?:0x)?[0-9a-f]+$/i.test(address) ? `address:${address.startsWith("0x") ? address : "0x" + address}` : "";
    }
    function toggleSpecial(name: string): void {
        if (!validSpecialName(name)) return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special(${luaString(name)})` : `togglespecialworkspace ${name}`);
    }
    function moveWindowToSpecial(address: string, name: string): void {
        const selector = selectorFor(address);
        if (!selector || !windowFor(address) || !validSpecialName(name)) return;
        const fullName = fullSpecialName(name);
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = ${luaString(selector)}, workspace = ${luaString(fullName)}, follow = false })` : `movetoworkspacesilent ${fullName},${selector}`);
    }
    function workspaceFor(id: int): var { return Hypr.workspaces.values.find(w => w.id === id) ?? null; }
    function activate(id: int): void {
        if (id < 1) return;
        const workspace = workspaceFor(id);
        if (workspace) workspace.activate();
        else Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${id}" })` : `workspace ${id}`);
    }
    function activateWindow(address: string): void {
        const client = windowFor(address);
        if (!client) return;
        if (client.workspace?.id > 0) client.workspace.activate();
        else {
            const name = canonicalSpecialName(client.workspace?.name ?? "");
            if (name !== null && !visibleMonitorForSpecial(name)) toggleSpecial(name);
        }
        if (client.wayland) client.wayland.activate();
        else {
            const selector = selectorFor(address);
            if (!selector) return;
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = ${luaString(selector)} })` : `focuswindow ${selector}`);
        }
    }
    function moveWindow(address: string, id: int): void {
        if (id < 1 || !windowFor(address)) return;
        const selector = selectorFor(address);
        if (!selector) return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = ${luaString(selector)}, workspace = "${id}", follow = false })` : `movetoworkspacesilent ${id},${selector}`);
    }
}
