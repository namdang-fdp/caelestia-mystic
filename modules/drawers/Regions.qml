pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Input follows visible controls and the utilities corner trigger.
Region {
    id: root
    required property Panels panels
    required property var win
    // Keep pointer motion on this surface while a slider owns the press, even
    // when a fast drag crosses the visible panel's input-region boundary.
    Region {
        width: root.panels.dashboard.dragging ? root.win.width : 0
        height: root.panels.dashboard.dragging ? root.win.height : 0
    }
    R { panel: root.panels.dashboard }
    R { panel: root.panels.dashboard.wifiPanel; offsetX: root.panels.dashboard.x; offsetY: root.panels.dashboard.y; extraWidth: 12 }
    R { panel: root.panels.dashboard.bluetoothPanel; offsetX: root.panels.dashboard.x - 12; offsetY: root.panels.dashboard.y; extraWidth: 12 }
    R { panel: root.panels.launcher; enabled: !root.win.hasFullscreen; height: panel.height * (1 - panel.offsetScale) }
    R { panel: root.panels.utilities; enabled: !root.win.hasFullscreen; height: panel.height * (1 - panel.offsetScale) }
    R { panel: root.panels.toasts; enabled: !root.win.hasFullscreen }
    Region {
        x: root.win.width - root.panels.utilities.activationWidth
        y: root.win.height - root.panels.utilities.activationHeight
        width: !root.win.hasFullscreen && root.panels.utilities.cornerEnabled ? root.panels.utilities.activationWidth : 0
        height: !root.win.hasFullscreen && root.panels.utilities.cornerEnabled ? root.panels.utilities.activationHeight : 0
    }
    component R: Region {
        required property Item panel
        property bool enabled: true
        property real offsetX: 0
        property real offsetY: 0
        property real extraWidth: 0
        x: panel.x + offsetX + root.win.borderThickness
        y: panel.y + offsetY + root.win.borderThickness
        width: enabled && panel.visible ? panel.width + extraWidth : 0
        height: enabled && panel.visible ? panel.height : 0
    }
}
