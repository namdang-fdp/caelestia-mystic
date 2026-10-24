pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services

// Right click menu for a dock item
PopupWindow {
    id: root

    required property DockWindow dock
    property DockItem target

    readonly property string key: target?.modelData ?? ""
    readonly property bool pinned: DockConfig.pinnedApps.includes(key)
    readonly property bool targetLeaving: !!target && !!dock.leaving[key]
    readonly property list<DesktopAction> actions: target?.entry?.actions ?? []

    function close(): void {
        visible = false;
    }

    anchor.item: target
    anchor.rect.x: target ? target.width / 2 : 0
    anchor.rect.y: target ? target.height - dock.pad - dock.iconSize - 10 : 0
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top

    implicitWidth: bg.implicitWidth
    implicitHeight: bg.implicitHeight
    color: "transparent"

    contentItem.Config.screen: dock.screen.name
    contentItem.Tokens.screen: dock.screen.name
    visible: false

    onTargetChanged: if (!target) close()
    onTargetLeavingChanged: if (targetLeaving) close()
    onVisibleChanged: {
        if (visible) {
            bg.opacity = 0;
            bg.scale = 0.94;
            openAnim.restart();
        }
    }

    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.close()
    }

    ParallelAnimation {
        id: openAnim

        Anim {
            target: bg
            property: "opacity"
            to: 1
            type: Anim.FastEffects
        }
        Anim {
            target: bg
            property: "scale"
            to: 1
            type: Anim.FastSpatial
        }
    }

    StyledRect {
        id: bg

        anchors.fill: parent
        implicitWidth: Math.min(320, Math.max(200, layout.implicitWidth + Tokens.padding.small * 2))
        implicitHeight: layout.implicitHeight + Tokens.padding.small * 2
        transformOrigin: Item.Bottom
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.6 : 0.45)

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: 0

            Repeater {
                model: root.target?.windows.slice(0, 8) ?? []

                MenuRow {
                    required property HyprlandToplevel modelData

                    text: modelData.title || root.target?.label || ""
                    icon: modelData === Hypr.activeToplevel ? "check" : ""
                    onTriggered: Dock.focus(modelData)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.padding.extraSmall
                Layout.bottomMargin: Tokens.padding.extraSmall
                Layout.leftMargin: Tokens.padding.medium
                Layout.rightMargin: Tokens.padding.medium
                visible: (root.target?.running ?? false)
                implicitHeight: 1
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
            }

            // Desktop actions, e.g. "New Private Window"
            Repeater {
                model: root.visible ? root.actions : []

                MenuRow {
                    required property DesktopAction modelData

                    text: modelData.name
                    onTriggered: {
                        if (Dock.runAction(root.key, modelData) && !root.target.running)
                            root.target.launching = true;
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.padding.extraSmall
                Layout.bottomMargin: Tokens.padding.extraSmall
                Layout.leftMargin: Tokens.padding.medium
                Layout.rightMargin: Tokens.padding.medium
                visible: root.actions.length > 0
                implicitHeight: 1
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
            }

            MenuRow {
                visible: !!root.target?.entry
                text: qsTr("New window")
                onTriggered: {
                    if (Dock.launch(root.key) && !root.target.running)
                        root.target.launching = true;
                }
            }

            MenuRow {
                visible: !!root.target?.entry
                text: root.pinned ? qsTr("Remove from Dock") : qsTr("Keep in Dock")
                onTriggered: root.pinned ? DockConfig.unpin(root.key) : DockConfig.pin(root.key)
            }

            MenuRow {
                visible: root.target?.running ?? false
                text: (root.target?.windows.length ?? 0) > 1 ? qsTr("Quit %1 windows").arg(root.target.windows.length) : qsTr("Quit")
                onTriggered: Dock.closeWindows(root.target.windows)
            }
        }
    }

    component MenuRow: Item {
        id: row

        property string text
        property string icon

        signal triggered

        Layout.fillWidth: true
        implicitWidth: rowText.implicitWidth + Tokens.padding.medium * 2 + Tokens.font.icon.small.pointSize * 2
        implicitHeight: rowText.implicitHeight + Tokens.padding.small * 2

        StateLayer {
            radius: Tokens.rounding.small
            onClicked: {
                row.triggered();
                root.close();
            }
        }

        MaterialIcon {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.small
            anchors.verticalCenter: parent.verticalCenter
            text: row.icon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            id: rowText

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tokens.padding.small + Tokens.font.icon.small.pointSize * 2
            anchors.rightMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            text: row.text
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }
}
