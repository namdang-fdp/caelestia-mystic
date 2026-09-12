pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.components.misc
import qs.services

Scope {
    id: root

    property ShellScreen targetScreen
    property string chipScreenName
    readonly property ShellScreen chipScreen: screenForName(chipScreenName)

    function screenForName(name: string): ShellScreen {
        return Screens.screens.find(screen => screen.name === name) ?? null;
    }

    function focusedScreen(): ShellScreen {
        const monitorName = Hypr.focusedMonitor?.name ?? "";
        return Screens.screens.find(screen => screen.name === monitorName)
            ?? Screens.screens[0]
            ?? null;
    }

    function ensureChipScreen(): void {
        if (screenForName(chipScreenName))
            return;
        chipScreenName = focusedScreen()?.name ?? "";
    }

    function open(): void {
        if (islandLoader.active)
            return;
        const screen = focusedScreen();
        if (!screen) {
            console.warn(lc, "Unable to open the LeetCode timer: no enabled screen is available");
            return;
        }
        LeetCodeTimer.prefillFromActiveWindow(false);
        targetScreen = screen;
        islandLoader.activeAsync = true;
    }

    function close(): void {
        if (!islandLoader.active)
            return;
        if (islandLoader.item)
            islandLoader.item.close();
        else
            islandLoader.activeAsync = false;
    }

    function toggle(): void {
        if (islandLoader.active)
            close();
        else
            open();
    }

    Connections {
        target: LeetCodeTimer

        function onSessionStarted(): void {
            root.chipScreenName = root.focusedScreen()?.name ?? "";
        }

        function onHasActiveSessionChanged(): void {
            if (LeetCodeTimer.hasActiveSession)
                root.ensureChipScreen();
        }
    }

    Connections {
        target: Screens

        function onScreensChanged(): void {
            root.ensureChipScreen();
        }
    }

    LazyLoader {
        id: islandLoader

        property bool closing

        LeetCodeTimerWindow {
            controller: root
            loader: islandLoader
            screen: root.targetScreen
        }
    }

    LazyLoader {
        id: chipLoader

        active: LeetCodeTimer.hasActiveSession && root.chipScreen !== null

        LeetCodeTimerChip {
            controller: root
            screen: root.chipScreen
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "leetcodeTimer"
        description: "Toggle LeetCode session timer"
        onPressed: root.toggle()
    }

    IpcHandler {
        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }

        function toggle(): void {
            root.toggle();
        }

        function isOpen(): bool {
            return islandLoader.active;
        }

        target: "leetcodeTimerUi"
    }

    Component.onCompleted: {
        if (LeetCodeTimer.hasActiveSession)
            ensureChipScreen();
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.leetcodetimer.ui"
        defaultLogLevel: LoggingCategory.Info
    }
}
