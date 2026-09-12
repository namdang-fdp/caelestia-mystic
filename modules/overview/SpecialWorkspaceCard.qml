pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

StyledClippingRect {
    id: root

    required property string specialWorkspaceName
    required property var overview

    readonly property var clientAddresses: overview.specialWindowAddresses(specialWorkspaceName)
    readonly property string fullWorkspaceName: overview.fullSpecialWorkspaceName(specialWorkspaceName)
    readonly property string displayName: overview.specialWorkspaceDisplayName(specialWorkspaceName)
    readonly property string monitorName: overview.visibleMonitorForSpecialWorkspace(specialWorkspaceName)
    readonly property string navigationKey: `special:${specialWorkspaceName}`
    readonly property string icon: Icons.getSpecialWsIcon(fullWorkspaceName)
    readonly property bool active: monitorName !== ""
    readonly property bool selected: overview.specialSelectionActive
        && overview.selectedSpecialWorkspaceName === specialWorkspaceName
    readonly property int windowColumns: Math.max(1, Math.ceil(Math.sqrt(clientAddresses.length)))
    readonly property int windowRows: Math.max(1, Math.ceil(clientAddresses.length / windowColumns))
    readonly property int innerSpacing: Tokens.spacing.small

    color: Colours.tPalette.m3surfaceContainerLow
    radius: Tokens.rounding.extraLarge
    border.width: selected ? 4 : active ? 3 : 1
    border.color: selected
        ? Colours.palette.m3secondary
        : active ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
    scale: selected ? 1.012 : 1

    Component.onCompleted: overview.registerSpecialWorkspaceCard(root)
    Component.onDestruction: overview.unregisterSpecialWorkspaceCard(root)

    StateLayer {
        z: 0
        radius: root.radius
        color: root.selected
            ? Colours.palette.m3secondary
            : root.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
        onClicked: {
            root.overview.selectSpecialWorkspace(root.specialWorkspaceName);
            root.overview.activateSpecialWorkspace(root.specialWorkspaceName);
        }
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
                implicitWidth: specialIcon.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: specialIcon.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.full
                color: root.active
                    ? Colours.palette.m3primary
                    : Colours.tPalette.m3surfaceContainerHighest

                MaterialIcon {
                    id: specialIcon

                    anchors.centerIn: parent
                    text: root.icon
                    color: root.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    fontStyle: Tokens.font.icon.medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.displayName
                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const count = root.clientAddresses.length;
                        const windows = count === 0
                            ? qsTr("Empty")
                            : qsTr("%1 window%2").arg(count).arg(count === 1 ? "" : "s");
                        return root.active
                            ? qsTr("%1 · visible on %2").arg(windows).arg(root.monitorName)
                            : windows;
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                visible: root.active || root.selected
                text: root.selected ? "keyboard_return" : "radio_button_checked"
                color: root.selected ? Colours.palette.m3secondary : Colours.palette.m3primary
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
                    // Address keys are retained by the overview. Each delegate resolves the
                    // current client immediately and disables capture as soon as it disappears.
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

                        visible: !!client
                            && root.overview.canonicalSpecialWorkspaceName(client.workspace?.name ?? "") === root.specialWorkspaceName
                            && root.overview.isSpecialWindow(client)
                        clientAddress: modelData
                        overview: root.overview
                        interactive: false
                        navigationEnabled: false
                        captureEnabled: visible && root.overview.captureEnabled
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: root.clientAddresses.length === 0
                spacing: Tokens.spacing.small

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.specialWorkspaceName === "" ? "star" : root.icon
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.25).build()
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("No open windows")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }
        }
    }

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
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
