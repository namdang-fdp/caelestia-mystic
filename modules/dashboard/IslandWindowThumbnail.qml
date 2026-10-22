pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Rectangle {
    id: root
    required property string clientAddress
    required property var workspaceView
    readonly property var client: IslandWorkspaces.windowFor(clientAddress)
    readonly property var ipcData: client?.lastIpcObject ?? ({})
    readonly property var monitor: client?.monitor
    readonly property int cell: workspaceView.cellFor(client)
    readonly property real headerHeight: workspaceView.headerHeight ?? 28
    readonly property real availableHeight: workspaceView.tileHeight - headerHeight
    readonly property real desktopWidth: (monitor?.width ?? workspaceView.screen.width) / (monitor?.scale ?? 1)
    readonly property real desktopHeight: (monitor?.height ?? workspaceView.screen.height) / (monitor?.scale ?? 1)
    readonly property real factor: Math.min((workspaceView.tileWidth - 12) / desktopWidth, availableHeight / desktopHeight)
    readonly property real insetX: ((workspaceView.tileWidth - 12) - desktopWidth * factor) / 2
    readonly property real insetY: (availableHeight - desktopHeight * factor) / 2
    readonly property real originX: (cell % 3) * (workspaceView.tileWidth + workspaceView.gap)
    readonly property real originY: Math.floor(cell / 3) * (workspaceView.tileHeight + workspaceView.gap)
    readonly property real homeX: originX + 6 + insetX + Math.max(0, Math.min(desktopWidth - (ipcData.size?.[0] ?? 500), (ipcData.at?.[0] ?? 0) - (monitor?.x ?? 0))) * factor
    readonly property real homeY: originY + headerHeight - 4 + insetY + Math.max(0, Math.min(desktopHeight - (ipcData.size?.[1] ?? 300), (ipcData.at?.[1] ?? 0) - (monitor?.y ?? 0))) * factor
    property bool dragInProgress: false
    readonly property bool dragging: dragInProgress
    visible: workspaceView.visible && !!client && cell >= 0 && cell < (workspaceView.cellCount ?? 6)
    width: Math.max(22, Math.min(workspaceView.tileWidth - 12, (ipcData.size?.[0] ?? 500) * factor))
    height: Math.max(18, Math.min(availableHeight, (ipcData.size?.[1] ?? 300) * factor))
    x: homeX
    y: homeY
    z: dragging ? 100 : client === Hypr.activeToplevel ? 2 : 1
    radius: 6
    color: IslandTheme.palette.m3surfaceContainerHighest
    border.width: client === Hypr.activeToplevel ? 2 : 1
    border.color: dragging || client === Hypr.activeToplevel ? IslandTheme.palette.m3primary : IslandTheme.palette.m3outlineVariant
    opacity: dragging ? 0.8 : 1
    Drag.active: dragging
    Drag.keys: ["island-window"]
    Drag.source: root
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    Drag.supportedActions: Qt.MoveAction
    Binding { target: root; property: "x"; value: root.homeX; when: !root.dragging; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "y"; value: root.homeY; when: !root.dragging; restoreMode: Binding.RestoreNone }
    IconImage {
        anchors.centerIn: parent
        width: Math.min(28, parent.width - 4)
        height: width
        source: Icons.getAppIcon(root.ipcData.class ?? "", "image-missing")
    }
    Loader {
        anchors.fill: parent
        anchors.margins: 2
        active: root.visible && !!root.client?.wayland
        sourceComponent: ScreencopyView {
            anchors.centerIn: parent
            captureSource: root.client?.wayland ?? null
            constraintSize: Qt.size(root.width - 4, root.height - 4)
            live: false
            paintCursor: false
        }
    }
    TapHandler {
        onTapped: { IslandWorkspaces.activateWindow(root.clientAddress); root.workspaceView.closeRequested(); }
    }
    DragHandler {
        id: drag
        target: root
        onActiveChanged: {
            if (active) root.dragInProgress = true;
            else {
                // Keep drop shelves mounted until the drop has been delivered.
                root.Drag.drop();
                root.dragInProgress = false;
            }
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: root.client?.title ?? qsTr("Window")
    Accessible.onPressAction: { IslandWorkspaces.activateWindow(root.clientAddress); root.workspaceView.closeRequested(); }
}
