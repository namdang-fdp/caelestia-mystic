import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.utilities as Utilities
import qs.modules.resources as ResourcesPanel
import qs.modules.utilities.toasts as Toasts

Item {
    id: root
    required property ShellScreen screen
    required property ScreenState screenState
    property bool fullscreen
    required property real borderThickness
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias agentCompanion: agentCompanion
    readonly property alias utilities: utilities
    readonly property alias resources: resources
    readonly property alias toasts: toasts
    anchors.fill: parent
    anchors.margins: borderThickness

    Launcher.Wrapper {
        id: launcher
        screen: root.screen
        screenState: root.screenState
        panels: root
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }
    Dashboard.IslandAgentCompanion {
        id: agentCompanion
        island: dashboard
        available: dashboard.Config.dashboard.enabled && IslandTools.agentNotch && !root.fullscreen
            && root.screen === Quickshell.screens.reduce((chosen, screen) => {
                if (!chosen) return screen;
                const internal = /^(eDP|LVDS|DSI)-/.test(screen.name);
                const chosenInternal = /^(eDP|LVDS|DSI)-/.test(chosen.name);
                if (internal !== chosenInternal) return internal ? chosen : screen;
                return screen.x < chosen.x ? screen : chosen;
            }, null)
    }
    Dashboard.IslandActivityBubble {
        id: activityBubble
        island: dashboard
        available: dashboard.Config.dashboard.enabled && !root.fullscreen
    }
    Dashboard.Wrapper {
        id: dashboard
        screenState: root.screenState
        screen: root.screen
        fullscreen: root.fullscreen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }
    Utilities.Wrapper {
        id: utilities
        screenState: root.screenState
        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }
    ResourcesPanel.Wrapper {
        id: resources
        screenState: root.screenState
        anchors.left: parent.left
        // Bottom-left, above the corner that opens it; it grows upward and its tab bar sits at the bottom, so
        // the tabs stay under the pointer while the content above changes height.
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
    }
    Toasts.Toasts {
        id: toasts
        anchors.bottom: utilities.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.medium
    }
}
