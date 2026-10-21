import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.utilities as Utilities
import qs.modules.utilities.toasts as Toasts

Item {
    id: root
    required property ShellScreen screen
    required property ScreenState screenState
    property bool fullscreen
    required property real borderThickness
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias utilities: utilities
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
    RectangularShadow {
        anchors.fill: dashboard
        radius: dashboard.surfaceRadius
        blur: dashboard.expanded || dashboard.previewOpen ? 28 : 10
        offset.y: dashboard.expanded || dashboard.previewOpen ? 8 : 2
        color: "#80000000"
        visible: dashboard.visible
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
    Toasts.Toasts {
        id: toasts
        anchors.bottom: utilities.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.medium
    }
}
