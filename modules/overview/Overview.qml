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

    LoggingCategory {
        id: lc

        name: "caelestia.qml.overview"
        defaultLogLevel: LoggingCategory.Info
    }
}
