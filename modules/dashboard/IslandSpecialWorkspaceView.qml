pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

FocusScope {
    id: root
    required property ShellScreen screen
    property real layoutTargetWidth: width
    property bool interactiveFocus: true
    property int page: 0
    readonly property int lastPage: Math.max(0, Math.ceil(IslandWorkspaces.specialNames.length / 6) - 1)
    onLastPageChanged: page = Math.min(page, lastPage)
    readonly property int startIndex: page * 6
    readonly property int cellCount: 6
    readonly property real gap: 8
    readonly property real tileWidth: (width - gap * 2) / 3
    readonly property real tileHeight: tileWidth * 0.56
    readonly property real headerHeight: 44
    readonly property int normalWorkspaceId: Math.max(1, Hypr.monitorFor(screen)?.activeWorkspace?.id ?? 1)
    property var thumbnailItems: []
    readonly property bool dragging: thumbnailItems.some(item => item?.dragging)
    implicitHeight: ((layoutTargetWidth - gap * 2) / 3 * 0.56) * 2 + gap + 46
    signal closeRequested

    function cellFor(client: var): int {
        const name = IslandWorkspaces.canonicalSpecialName(client?.workspace?.name ?? "");
        return name === null ? -1 : IslandWorkspaces.specialNames.indexOf(name) - startIndex;
    }
    function activate(name: string): void { IslandWorkspaces.toggleSpecial(name); closeRequested(); }
    Keys.onPressed: event => {
        if (!root.interactiveFocus) return;
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
            const name = IslandWorkspaces.specialNames[root.startIndex + event.key - Qt.Key_1];
            if (name !== undefined) root.activate(name);
        } else if (event.key === Qt.Key_Left) root.page = Math.max(0, root.page - 1);
        else if (event.key === Qt.Key_Right && root.startIndex + 6 < IslandWorkspaces.specialNames.length) root.page++;
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
                readonly property string specialName: IslandWorkspaces.specialNames[root.startIndex + index] ?? ""
                readonly property string monitorName: IslandWorkspaces.visibleMonitorForSpecial(specialName)
                readonly property bool active: !!monitorName
                readonly property int windowCount: IslandWorkspaces.specialWindows.filter(t => IslandWorkspaces.canonicalSpecialName(t.workspace?.name ?? "") === specialName).length
                visible: root.startIndex + index < IslandWorkspaces.specialNames.length
                x: (index % 3) * (root.tileWidth + root.gap)
                y: Math.floor(index / 3) * (root.tileHeight + root.gap)
                width: root.tileWidth
                height: root.tileHeight
                radius: 16
                color: drop.containsDrag || hover.hovered ? IslandTheme.palette.m3surfaceContainerHighest : IslandTheme.palette.m3surfaceContainerHigh
                border.width: active || drop.containsDrag ? 2 : 1
                border.color: active || drop.containsDrag ? IslandTheme.palette.m3primary : Qt.alpha(IslandTheme.palette.m3outline, 0.15)
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Toggle special workspace %1").arg(IslandWorkspaces.specialDisplayName(specialName))
                Accessible.onPressAction: root.activate(specialName)
                HoverHandler { id: hover }
                TapHandler { onTapped: root.activate(tile.specialName) }
                DropArea {
                    id: drop
                    anchors.fill: parent
                    keys: ["island-window"]
                    onDropped: event => {
                        IslandWorkspaces.moveWindowToSpecial(event.source.clientAddress, tile.specialName);
                        event.acceptProposedAction();
                    }
                }
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 6
                    MaterialIcon {
                        text: Icons.getSpecialWsIcon(IslandWorkspaces.fullSpecialName(tile.specialName))
                        fontStyle: Tokens.font.icon.small
                        color: tile.active ? IslandTheme.palette.m3primary : IslandTheme.palette.m3onSurfaceVariant
                    }
                    IslandText {
                        Layout.fillWidth: true
                        text: IslandWorkspaces.specialDisplayName(tile.specialName)
                        elide: Text.ElideRight
                        islandFont: Tokens.font.label.medium
                        color: tile.active ? IslandTheme.palette.m3primary : IslandTheme.palette.m3onSurfaceVariant
                    }
                    IslandText {
                        text: tile.windowCount.toString()
                        islandFont: Tokens.font.label.small
                        color: IslandTheme.palette.m3outline
                    }
                }
                IslandText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 29
                    visible: tile.active
                    text: qsTr("Visible on %1").arg(tile.monitorName)
                    elide: Text.ElideRight
                    islandFont: Tokens.font.label.small
                    color: IslandTheme.palette.m3primary
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 10
                    visible: tile.windowCount === 0
                    text: "add"
                    fontStyle: Tokens.font.icon.large
                    color: Qt.alpha(IslandTheme.palette.m3outline, 0.5)
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
        IslandButton { iconName: "chevron_left"; enabled: root.page > 0; Accessible.name: qsTr("Previous special workspaces"); onClicked: root.page-- }
        IslandText {
            text: qsTr("%1–%2").arg(root.startIndex + 1).arg(Math.min(root.startIndex + 6, IslandWorkspaces.specialNames.length))
            islandFont: Tokens.font.label.medium
            color: IslandTheme.palette.m3onSurfaceVariant
        }
        IslandButton { iconName: "chevron_right"; enabled: root.startIndex + 6 < IslandWorkspaces.specialNames.length; Accessible.name: qsTr("Next special workspaces"); onClicked: root.page++ }
        Item { Layout.fillWidth: true }
        IslandButton {
            id: regularTarget
            text: qsTr("Workspace %1").arg(root.normalWorkspaceId)
            iconName: "grid_view"
            checked: normalDrop.containsDrag
            Accessible.name: qsTr("Open workspace %1, or drop a window here to move it back").arg(root.normalWorkspaceId)
            onClicked: { IslandWorkspaces.activate(root.normalWorkspaceId); root.closeRequested(); }
            DropArea {
                id: normalDrop
                anchors.fill: parent
                keys: ["island-window"]
                onDropped: event => {
                    IslandWorkspaces.moveWindow(event.source.clientAddress, root.normalWorkspaceId);
                    event.acceptProposedAction();
                }
            }
        }
    }
    onInteractiveFocusChanged: if (interactiveFocus && visible) forceActiveFocus()
    onVisibleChanged: if (visible && interactiveFocus) forceActiveFocus()
    Component.onCompleted: { IslandWorkspaces.overviewViewers++; if (interactiveFocus && visible) forceActiveFocus(); }
    Component.onDestruction: IslandWorkspaces.overviewViewers--
}
