pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import "../dashboard/helpers/ResourceLogic.js" as Logic

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
    function inResourcesArea(x: real, y: real): bool {
        const p = panels.resources;
        if (Logic.cornerActive({ x: x, y: y, width: width, height: height, zoneWidth: p.activationWidth, zoneHeight: p.activationHeight, pressed: pressed, fullscreen: fullscreen })) return true;
        return p.visible && Logic.inPanel(x, y, borderThickness + p.x, p.width, borderThickness + p.y, p.height, 10);
    }
    function updateResourcesHover(): void {
        if (fullscreen) return;
        const show = inResourcesArea(mouseX, mouseY);
        if (!show) resourcesEnterTimer.stop();
        if (show) {
            resourcesLeaveTimer.stop();
            if (!screenState.resources && !resourcesEnterTimer.running) resourcesEnterTimer.start();
        } else if (screenState.resources && !resourcesLeaveTimer.running) resourcesLeaveTimer.start();
    }
    Timer {
        id: resourcesEnterTimer
        interval: 120
        onTriggered: {
            if (!root.fullscreen && root.containsMouse && root.inResourcesArea(root.mouseX, root.mouseY)) root.screenState.resources = true;
        }
    }
    Timer {
        id: resourcesLeaveTimer
        interval: 250
        onTriggered: {
            if (!(root.containsMouse && root.inResourcesArea(root.mouseX, root.mouseY))) root.screenState.resources = false;
        }
    }
    function updateUtilitiesHover(): void {
        if (fullscreen) return;
        const show = inUtilitiesArea(mouseX, mouseY);
        if (!show) utilitiesEnterTimer.stop();
        if (!utilitiesShortcutActive) {
            if (show) {
                utilitiesLeaveTimer.stop();
                if (!screenState.utilities && !utilitiesEnterTimer.running) utilitiesEnterTimer.start();
            } else if (screenState.utilities && !utilitiesLeaveTimer.running) utilitiesLeaveTimer.start();
        } else if (show) utilitiesShortcutActive = false;
    }
    Timer {
        id: utilitiesEnterTimer
        interval: 200
        onTriggered: {
            if (!root.fullscreen && root.containsMouse && root.inUtilitiesArea(root.mouseX, root.mouseY)) root.screenState.utilities = true;
        }
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
    onEntered: {
        updateUtilitiesHover();
        updateResourcesHover();
    }
    onContainsMouseChanged: {
        if (!containsMouse) {
            resourcesEnterTimer.stop();
            resourcesLeaveTimer.restart();
            utilitiesEnterTimer.stop();
            if (!utilitiesShortcutActive) utilitiesLeaveTimer.restart();
        }
    }
    onPositionChanged: event => {
        if (fullscreen) return;
        if (Config.launcher.showOnHover) {
            if (!screenState.launcher && inBottomPanel(panels.launcher, event.x, event.y)) screenState.launcher = true;
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, event.x)) {
            if (event.y - dragStart.y < -Config.launcher.dragThreshold) screenState.launcher = true;
            else if (event.y - dragStart.y > Config.launcher.dragThreshold) screenState.launcher = false;
        }
        updateUtilitiesHover();
        updateResourcesHover();
    }
    Connections {
        target: root.screenState
        function onUtilitiesChanged(): void {
            root.utilitiesShortcutActive = root.screenState.utilities && !root.inUtilitiesArea(root.mouseX, root.mouseY);
            if (!root.screenState.utilities) utilitiesLeaveTimer.stop();
        }
    }
}
