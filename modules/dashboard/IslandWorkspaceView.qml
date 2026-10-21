pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

FocusScope {
    id: root
    required property ShellScreen screen
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    property int page: Math.floor((activeId - 1) / 6)
    readonly property int startId: page * 6 + 1
    readonly property real gap: 8
    readonly property real tileWidth: (width - gap * 2) / 3
    readonly property real tileHeight: tileWidth * 0.56
    property real layoutTargetWidth: width
    property bool interactiveFocus: true
    property var thumbnailItems: []
    readonly property bool dragging: thumbnailItems.some(item => item?.dragging)
    function cellFor(client: var): int { return client?.workspace?.id > 0 ? client.workspace.id - startId : -1; }
    signal closeRequested
    // Measure the destination geometry instead of retargeting height on every
    // frame of the capsule's width morph.
    implicitHeight: ((layoutTargetWidth - gap * 2) / 3 * 0.56) * 2 + gap + 46
    function activate(id: int): void { IslandWorkspaces.activate(id); closeRequested(); }
    onActiveIdChanged: page = Math.floor((activeId - 1) / 6)
    Keys.onPressed: event => {
        if (!root.interactiveFocus) return;
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) root.activate(root.startId + event.key - Qt.Key_1);
        else if (event.key === Qt.Key_Left) root.page = Math.max(0, root.page - 1);
        else if (event.key === Qt.Key_Right) root.page++;
        else return;
        event.accepted = true;
    }
    Item {
        id: stage
        width: parent.width
        height: root.tileHeight * 2 + root.gap
        Repeater {
            model: 6
            Rectangle {
                id: tile
                required property int index
                readonly property int workspaceId: root.startId + index
                readonly property bool active: workspaceId === root.activeId
                x: (index % 3) * (root.tileWidth + root.gap)
                y: Math.floor(index / 3) * (root.tileHeight + root.gap)
                width: root.tileWidth
                height: root.tileHeight
                radius: 16
                color: drop.containsDrag || hover.hovered ? IslandTheme.palette.m3surfaceContainerHighest : IslandTheme.palette.m3surfaceContainerHigh
                border.width: active || drop.containsDrag ? 2 : 1
                border.color: active || drop.containsDrag ? IslandTheme.palette.m3primary : Qt.alpha(IslandTheme.palette.m3outline, 0.15)
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Workspace %1").arg(workspaceId)
                Accessible.onPressAction: root.activate(workspaceId)
                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: Wallpapers.current
                    sourceSize: Qt.size(root.tileWidth * 2, root.tileHeight * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 0.12
                }
                HoverHandler { id: hover }
                TapHandler { onTapped: root.activate(tile.workspaceId) }
                DropArea {
                    id: drop
                    anchors.fill: parent
                    keys: ["island-window"]
                    onDropped: event => {
                        IslandWorkspaces.moveWindow(event.source.clientAddress, tile.workspaceId);
                        event.acceptProposedAction();
                    }
                }
                IslandText {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 10
                    text: tile.workspaceId.toString()
                    color: tile.active ? IslandTheme.palette.m3primary : IslandTheme.palette.m3onSurfaceVariant
                    islandFont: Tokens.font.label.medium
                }
            }
        }
        Repeater {
            id: thumbnails
            model: IslandWorkspaces.windowAddresses
            onItemAdded: (index, item) => root.thumbnailItems = root.thumbnailItems.concat([item])
            onItemRemoved: (index, item) => root.thumbnailItems = root.thumbnailItems.filter(existing => existing !== item)
            IslandWindowThumbnail {
                required property string modelData
                clientAddress: modelData
                workspaceView: root
            }
        }
    }
    RowLayout {
        anchors.top: stage.bottom
        anchors.topMargin: 8
        width: parent.width
        IslandButton { iconName: "chevron_left"; enabled: root.page > 0; Accessible.name: qsTr("Previous workspaces"); onClicked: root.page-- }
        IslandText { text: `${root.startId}–${root.startId + 5}`; islandFont: Tokens.font.label.medium; color: IslandTheme.palette.m3onSurfaceVariant }
        IslandButton { iconName: "chevron_right"; Accessible.name: qsTr("Next workspaces"); onClicked: root.page++ }
        Item { Layout.fillWidth: true }
        IslandText {
            visible: root.width >= 500 && !root.dragging
            text: qsTr("Click to focus · Drag a window to move")
            islandFont: Tokens.font.label.small
            color: IslandTheme.palette.m3outline
        }
    }
    onInteractiveFocusChanged: if (interactiveFocus && visible) forceActiveFocus()
    onVisibleChanged: if (visible && interactiveFocus) forceActiveFocus()
    Component.onCompleted: { IslandWorkspaces.overviewViewers++; if (interactiveFocus && visible) forceActiveFocus(); }
    Component.onDestruction: IslandWorkspaces.overviewViewers--
}
