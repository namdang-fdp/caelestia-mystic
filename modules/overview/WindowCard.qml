pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

StyledClippingRect {
    id: root

    required property string clientAddress
    required property var overview
    required property bool captureEnabled
    property bool interactive: true
    property bool navigationEnabled: true

    readonly property HyprlandToplevel client: overview.windowForAddress(clientAddress)
    readonly property string address: clientAddress
    readonly property string navigationKey: `window:${address}`
    readonly property bool selected: navigationEnabled && !overview.specialSelectionActive && overview.selectedAddress === address
    readonly property bool focused: !!client && (client === Hypr.activeToplevel || client.activated)
    readonly property string appId: client?.lastIpcObject?.class
        || client?.wayland?.appId
        || client?.lastIpcObject?.initialClass
        || qsTr("Application")
    readonly property string title: client?.title || client?.lastIpcObject?.title || appId
    property bool hovered
    readonly property int footerHeight: Math.max(42, Math.round(height * 0.22))

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.largeIncreased
    border.width: selected ? 4 : focused ? 2 : 1
    border.color: selected || focused
        ? Colours.palette.m3secondary
        : hovered ? Colours.palette.m3outline : Colours.palette.m3outlineVariant
    scale: selected ? 1.015 : hovered ? 1.01 : 1

    Component.onCompleted: {
        if (navigationEnabled)
            overview.registerWindowCard(root);
        if (client && !client.wayland)
            overview.warnPreview(client, qsTr("no screencopy-compatible Wayland toplevel is available"));
    }
    Component.onDestruction: {
        if (navigationEnabled)
            overview.unregisterWindowCard(root);
    }

    Item {
        id: previewArea

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top

        StyledRect {
            anchors.fill: parent
            color: Colours.tPalette.m3surfaceContainerHighest

            Column {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - Tokens.padding.large * 2)
                spacing: Tokens.spacing.small

                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(64, Math.max(32, previewArea.height * 0.34))
                    height: width
                    source: Icons.getAppIcon(root.appId, "image-missing")
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.appId
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }

        Loader {
            id: previewLoader

            asynchronous: true
            anchors.fill: parent
            active: root.captureEnabled && !!root.client?.wayland

            sourceComponent: ScreencopyView {
                id: preview

                anchors.centerIn: parent
                captureSource: root.client?.wayland ?? null
                live: false
                paintCursor: false
                opacity: hasContent ? 1 : 0

                constraintSize.width: previewArea.width
                constraintSize.height: previewArea.height

                onStopped: {
                    if (root.client && !hasContent)
                        root.overview.warnPreview(root.client, qsTr("screencopy stopped before producing a frame"));
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }
    }

    StyledRect {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: root.footerHeight
        color: Colours.tPalette.m3surfaceContainerHigh

        Row {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(28, footer.height - Tokens.padding.small * 2)
                height: width
                source: Icons.getAppIcon(root.appId, "image-missing")
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - x - focusIndicator.width - parent.spacing)
                spacing: 0

                StyledText {
                    width: parent.width
                    text: root.title
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.appId
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.builders.small.size(11).build()
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                id: focusIndicator

                anchors.verticalCenter: parent.verticalCenter
                visible: root.focused || root.selected
                text: root.selected ? "keyboard_return" : "radio_button_checked"
                color: Colours.palette.m3secondary
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3secondary
        opacity: root.hovered ? 0.08 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive && !!root.client
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: {
            root.overview.selectWindow(root.address);
            root.overview.activateWindow(root.client);
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
