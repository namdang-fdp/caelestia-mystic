pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property int workspaceId
    required property var overview

    readonly property HyprlandWorkspace workspace: overview.workspaceForId(workspaceId)
    readonly property var windows: overview.windows.filter(client => client.workspace?.id === workspaceId)
    readonly property bool active: !!workspace && (workspace === Hypr.focusedWorkspace || workspace.focused)
    readonly property int windowColumns: Math.max(1, Math.ceil(Math.sqrt(windows.length)))
    readonly property int windowRows: Math.max(1, Math.ceil(windows.length / windowColumns))
    readonly property int innerSpacing: Tokens.spacing.medium

    visible: !!workspace
    color: Colours.tPalette.m3surfaceContainerLow
    radius: Tokens.rounding.extraLarge
    border.width: active ? 3 : 1
    border.color: active ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

    StateLayer {
        z: 0
        radius: root.radius
        color: root.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
        disabled: !root.workspace
        onClicked: root.overview.activateWorkspace(root.workspace)
    }

    ColumnLayout {
        z: 1
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: workspaceLabel.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: workspaceLabel.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.full
                color: root.active ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                StyledText {
                    id: workspaceLabel

                    anchors.centerIn: parent
                    text: root.workspaceId.toString()
                    color: root.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: !root.workspace || root.workspace.name === root.workspaceId.toString()
                        ? qsTr("Workspace %1").arg(root.workspaceId)
                        : root.workspace.name
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.windows.length === 0
                        ? qsTr("Empty")
                        : qsTr("%1 window%2").arg(root.windows.length).arg(root.windows.length === 1 ? "" : "s")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                visible: root.active
                text: "radio_button_checked"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }
        }

        Item {
            id: windowArea

            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                anchors.fill: parent
                columns: root.windowColumns
                columnSpacing: root.innerSpacing
                rowSpacing: root.innerSpacing

                Repeater {
                    model: root.overview.windowAddresses

                    WindowCard {
                        required property string modelData

                        Layout.preferredWidth: visible
                            ? (windowArea.width - root.innerSpacing * (root.windowColumns - 1)) / root.windowColumns
                            : 0
                        Layout.preferredHeight: visible
                            ? (windowArea.height - root.innerSpacing * (root.windowRows - 1)) / root.windowRows
                            : 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        visible: !!client && client.workspace?.id === root.workspaceId && root.overview.isNormalWindow(client)
                        clientAddress: modelData
                        overview: root.overview
                        captureEnabled: visible && root.overview.captureEnabled
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: root.windows.length === 0
                spacing: Tokens.spacing.small

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "space_dashboard"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.5).build()
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("No open windows")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.medium
                }
            }
        }
    }

    Behavior on border.width {
        Anim {
            type: Anim.FastEffects
        }
    }

    Behavior on border.color {
        CAnim {}
    }
}
