import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components.misc
import qs.services
import qs.modules.nexus

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "nexus"
        description: "Open nexus"
        onPressed: WindowFactory.create()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "showall"
        description: "Toggle Island controls"
        onPressed: root.toggleIsland("controls")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboard"
        description: "Toggle Dynamic Island (Dashboard compatibility)"
        onPressed: root.toggleIsland()
    }

    function toggleIsland(page = ""): void {
        const state = ShellState.forActive();
        const island = ShellState.componentsForActive()?.panels?.dashboard;
        if (!state || !island || !island.Config.dashboard.enabled)
            return;
        if (state.dashboard && (!page || island.page === page)) island.close();
        else island.openPage(page || "controls");
    }

    function islandClose(): void { ShellState.componentsForActive()?.panels?.dashboard?.close(); }

    CustomShortcut {
        name: "dynamicIsland"
        description: "Toggle Dynamic Island"
        onPressed: root.toggleIsland()
    }

    CustomShortcut {
        name: "islandInfo"
        description: "Toggle Island Info"
        onPressed: root.toggleIsland("info")
    }

    CustomShortcut {
        name: "islandWindows"
        description: "Toggle Island Windows"
        onPressed: root.toggleIsland("workspaces")
    }

    CustomShortcut {
        name: "islandClipboard"
        description: "Open Island clipboard history"
        onPressed: {
            const island = ShellState.componentsForActive()?.panels?.dashboard;
            const state = ShellState.forActive();
            if (island?.expanded && island.page === "clipboard") state.dashboard = false;
            else island?.openPage("clipboard");
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "session"
        description: "Toggle Island power menu"
        onPressed: root.toggleIsland("power")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted && !root.hasFullscreen) {
                const screenState = ShellState.forActive();
                screenState.launcher = !screenState.launcher;
            }
            root.launcherInterrupted = false;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "sidebar"
        description: "Toggle Island notification history"
        onPressed: root.toggleIsland("notifications")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.utilities = !screenState.utilities;
        }
    }

    IpcHandler {
        function toggle(drawer: string): void {
            if (drawer === "dynamicIsland") drawer = "dashboard";
            if (["session", "sidebar", "osd"].includes(drawer)) {
                root.toggleIsland(drawer === "session" ? "power" : drawer === "sidebar" ? "notifications" : "controls");
                return;
            }
            if (drawer === "dashboard") {
                root.toggleIsland();
                return;
            }
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                const screenState = ShellState.forActive();
                screenState[drawer] = !screenState[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const screenState = ShellState.forActive();
            if (!screenState)
                return "";
            return Object.keys(screenState).filter(k => typeof screenState[k] === "boolean").join("\n");
        }

        function isOpen(drawer: string): string {
            if (drawer === "dynamicIsland") drawer = "dashboard";
            const screenState = ShellState.forActive();
            if (screenState && ["session", "sidebar", "osd"].includes(drawer)) {
                const page = drawer === "session" ? "power" : drawer === "sidebar" ? "notifications" : "controls";
                return screenState.dashboard && screenState.islandPage === page ? "1" : "0";
            }
            if (!screenState || typeof screenState[drawer] !== "boolean")
                return "unknown";
            return screenState[drawer] ? "1" : "0";
        }

        target: "drawers"
    }

    IpcHandler {
        function open(tab: string): void {
            const state = ShellState.forActive();
            const island = ShellState.componentsForActive()?.panels?.dashboard;
            if (!state || !island || !island.Config.dashboard.enabled)
                return;
            island.openPage(["workspaces", "media", "clipboard", "info", "controls", "more", "notifications", "power", "connections"].includes(tab) ? tab : "controls");
        }

        function detail(section: string): void {
            if (["wifi", "bluetooth"].includes(section)) ShellState.componentsForActive()?.panels?.dashboard?.toggleDetail(section);
        }

        function back(): void { ShellState.componentsForActive()?.panels?.dashboard?.closeTop(); }

        function close(): void {
            root.islandClose();
        }

        function toggle(): void { root.toggleIsland(); }

        function status(): string {
            const state = ShellState.forActive();
            const island = ShellState.componentsForActive()?.panels?.dashboard;
            if (!state || !island)
                return "{}";
            return JSON.stringify({screen: state.modelData.name, expanded: island.expanded,
                visible: island.visible, preview: island.previewOpen, tab: state.dashboardTab,
                page: island.page, mode: island.mode, notificationExpanded: island.notificationExpanded,
                wifiOpen: island.wifiOpen, bluetoothOpen: island.bluetoothOpen, inlineDetails: island.inlineDetails,
                activity: island.activity,
                resizeMode: WindowUx.resizing, fontFamily: IslandTheme.fontFamily,
                hovered: island.hovered, previewAllowed: island.previewAllowed,
                width: island.width, height: island.height, popups: island.pending.length,
                notifications: Notifs.notClosed.length,
                retainedClosedNotifications: Notifs.list.filter(n => n.closed).length,
                workspaceIds: IslandWorkspaces.workspaceIds,
                windows: IslandWorkspaces.windows.length,
                clipboardItems: IslandClipboard.entries.length, clipboardError: IslandClipboard.error,
                trayItems: island.trayItems.map(item => ({id: item.id, title: item.title, hasMenu: item.hasMenu, onlyMenu: item.onlyMenu})),
                nativeMenuOpen: island.nativeMenuOpen, dragging: island.dragging,
                brightnessTarget: island.brightnessTarget,
                noSleep: IdleInhibitor.enabled,
                microphoneMuted: Audio.sourceMuted, volume: Audio.volume, recording: Recorder.running, recordingPaused: Recorder.paused,
                healthWarning: IslandHealth.warning, cpuTemperature: IslandHealth.temperature,
                utilities: state.utilities, launcher: state.launcher,
                legacyBarLoaded: !!ShellState.componentsForActive()?.bar,
                mediaPlaying: Players.active?.isPlaying ?? false,
                audioPeak: Math.max(0, ...Audio.cava.values)});
        }

        target: "dynamicIsland"
    }

    IpcHandler {
        function open(): void {
            WindowFactory.create();
        }

        target: "nexus"
    }

    IpcHandler {
        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }

        target: "toaster"
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}
