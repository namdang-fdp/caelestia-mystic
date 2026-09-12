pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components.misc
import qs.services

Scope {
    id: root

    property ShellScreen targetScreen

    function focusedScreen(): ShellScreen {
        const monitor = Hypr.focusedMonitor;
        return Screens.screens.find(screen => Hypr.monitorFor(screen) === monitor) ?? null;
    }

    function open(): void {
        if (overviewLoader.active)
            return;

        const screen = focusedScreen();
        if (!screen) {
            console.warn(lc, "Unable to open workspace overview: the focused Hyprland monitor has no enabled shell screen");
            return;
        }

        targetScreen = screen;
        overviewLoader.activeAsync = true;
    }

    function close(): void {
        if (!overviewLoader.active)
            return;

        if (overviewLoader.item)
            overviewLoader.item.close();
        else
            overviewLoader.activeAsync = false;
    }

    function toggle(): void {
        if (overviewLoader.active) {
            if (overviewLoader.item)
                overviewLoader.item.close();
            else
                overviewLoader.activeAsync = false;
            return;
        }

        const screen = focusedScreen();
        if (!screen) {
            console.warn(lc, "Unable to open workspace overview: the focused Hyprland monitor has no enabled shell screen");
            return;
        }

        targetScreen = screen;
        overviewLoader.activeAsync = true;
    }

    LazyLoader {
        id: overviewLoader

        property bool closing

        OverviewWindow {
            loader: overviewLoader
            screen: root.targetScreen
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "workspaceOverview"
        description: "Toggle workspace overview"
        onPressed: root.toggle()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "workspaceOverviewOpen"
        description: "Open workspace overview"
        onPressed: root.open()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "workspaceOverviewClose"
        description: "Close workspace overview"
        onPressed: root.close()
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.overview"
        defaultLogLevel: LoggingCategory.Info
    }
}
