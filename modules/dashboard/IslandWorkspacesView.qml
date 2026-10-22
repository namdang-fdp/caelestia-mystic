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
    property bool specialSelected: false
    readonly property bool dragging: normal.dragging || special.dragging
    implicitHeight: normal.implicitHeight + 42
    signal closeRequested
    RowLayout {
        id: tabs
        width: parent.width
        height: 36
        spacing: 6
        IslandButton {
            iconName: "grid_view"
            text: qsTr("Normal")
            checked: !root.specialSelected
            onClicked: root.specialSelected = false
        }
        IslandButton {
            iconName: "layers"
            text: qsTr("Special")
            checked: root.specialSelected
            onClicked: root.specialSelected = true
        }
        Item { Layout.fillWidth: true }
        IslandText {
            visible: root.specialSelected && root.width >= 530
            text: root.specialSelected ? qsTr("Click to toggle · Drag to move") : qsTr("Click to focus · Drag to move")
            islandFont: Tokens.font.label.small
            color: IslandTheme.palette.m3outline
        }
    }
    IslandWorkspaceView {
        id: normal
        anchors.top: tabs.bottom
        anchors.topMargin: 6
        width: parent.width
        height: implicitHeight
        screen: root.screen
        layoutTargetWidth: root.layoutTargetWidth
        interactiveFocus: root.interactiveFocus && !root.specialSelected
        visible: !root.specialSelected
        onCloseRequested: root.closeRequested()
    }
    IslandSpecialWorkspaceView {
        id: special
        anchors.top: tabs.bottom
        anchors.topMargin: 6
        width: parent.width
        height: implicitHeight
        screen: root.screen
        layoutTargetWidth: root.layoutTargetWidth
        interactiveFocus: root.interactiveFocus && root.specialSelected
        visible: root.specialSelected
        onCloseRequested: root.closeRequested()
    }
    // While dragging, the footer becomes a shelf of direct special-workspace
    // destinations. This preserves the drag source and avoids changing pages.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 38
        visible: normal.dragging && !root.specialSelected
        color: IslandTheme.palette.m3surfaceContainerLow
        radius: 12
        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: targets.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            Row {
                id: targets
                spacing: 4
                Repeater {
                    model: IslandWorkspaces.specialNames
                    IslandButton {
                        id: target
                        required property string modelData
                        text: IslandWorkspaces.specialDisplayName(modelData)
                        iconName: Icons.getSpecialWsIcon(IslandWorkspaces.fullSpecialName(modelData))
                        checked: drop.containsDrag
                        Accessible.name: qsTr("Move window to %1").arg(text)
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            keys: ["island-window"]
                            onDropped: event => {
                                IslandWorkspaces.moveWindowToSpecial(event.source.clientAddress, target.modelData);
                                event.acceptProposedAction();
                            }
                        }
                    }
                }
            }
        }
    }
}
