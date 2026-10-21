pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls

CustomMouseArea {
    id: root
    required property ShellScreen screen
    required property ScreenState screenState
    required property Panels panels
    required property real borderThickness
    required property bool fullscreen
    property point dragStart
    property bool utilitiesShortcutActive
    function withinPanelWidth(panel: Item, x: real): bool {
        const left = borderThickness + panel.x;
        return x >= left - Config.border.rounding && x <= left + panel.width + Config.border.rounding;
    }
    function inBottomPanel(panel: Item, x: real, y: real, corner = false): bool {
        const h = panel.height * (1 - (panel.offsetScale ?? 0));
        return y > height - Math.max(Config.border.minThickness, borderThickness + h) - (corner ? Config.border.rounding : 0) && withinPanelWidth(panel, x);
    }
    function inUtilitiesArea(x: real, y: real): bool {
        const corner = x >= width - panels.utilities.activationWidth && y >= height - panels.utilities.activationHeight;
        return Config.utilities.enabled && (corner || panels.utilities.visible && inBottomPanel(panels.utilities, x, y, true));
    }
    Timer {
        id: utilitiesLeaveTimer
        interval: 180
        onTriggered: {
            if (!root.utilitiesShortcutActive && !(root.containsMouse && root.inUtilitiesArea(root.mouseX, root.mouseY))) root.screenState.utilities = false;
        }
    }
    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: true
    onPressed: event => dragStart = Qt.point(event.x, event.y)
    onContainsMouseChanged: if (!containsMouse && !utilitiesShortcutActive) utilitiesLeaveTimer.restart()
    onPositionChanged: event => {
        if (fullscreen) return;
        if (Config.launcher.showOnHover) {
            if (!screenState.launcher && inBottomPanel(panels.launcher, event.x, event.y)) screenState.launcher = true;
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, event.x)) {
            if (event.y - dragStart.y < -Config.launcher.dragThreshold) screenState.launcher = true;
            else if (event.y - dragStart.y > Config.launcher.dragThreshold) screenState.launcher = false;
        }
        const show = inUtilitiesArea(event.x, event.y);
        if (!utilitiesShortcutActive) {
            if (show) { utilitiesLeaveTimer.stop(); screenState.utilities = true; }
            else if (screenState.utilities && !utilitiesLeaveTimer.running) utilitiesLeaveTimer.start();
        }
        else if (show) utilitiesShortcutActive = false;
    }
    Connections {
        target: root.screenState
        function onUtilitiesChanged(): void {
            root.utilitiesShortcutActive = root.screenState.utilities && !root.inUtilitiesArea(root.mouseX, root.mouseY);
            if (!root.screenState.utilities) utilitiesLeaveTimer.stop();
        }
    }
}
