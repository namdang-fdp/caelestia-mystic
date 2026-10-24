pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

// Window thumbnails shown above a hovered running app
PopupWindow {
    id: root

    required property DockWindow dock
    property DockItem target

    readonly property list<HyprlandToplevel> windows: target?.windows ?? []
    readonly property bool hovered: hover.hovered
    readonly property real thumbWidth: Math.round(Math.max(120, Math.min(220, dock.screen.width * 0.8 / Math.max(1, windows.length) - 16)))
    readonly property real thumbHeight: Math.round(thumbWidth * 0.62)

    function show(item: DockItem): void {
        target = item;
        visible = true;
    }

    function close(): void {
        visible = false;
    }

    anchor.item: target
    anchor.rect.x: target ? target.width / 2 : 0
    anchor.rect.y: target ? target.height - dock.pad - dock.iconSize * dock.maxZoom - 8 : 0
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

    onWindowsChanged: if (visible && windows.length === 0) close()
    onTargetChanged: if (!target) close()
    onVisibleChanged: {
        if (visible) {
            bg.opacity = 0;
            bg.scale = 0.94;
            openAnim.restart();
        }
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
        implicitWidth: row.implicitWidth + Tokens.padding.small * 2
        implicitHeight: row.implicitHeight + Tokens.padding.small * 2
        transformOrigin: Item.Bottom
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.6 : 0.45)

        HoverHandler {
            id: hover
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 0

            Repeater {
                // Thumbnails are only captured while the popup is open
                model: root.visible ? root.windows : []

                Thumbnail {}
            }
        }
    }

    component Thumbnail: Item {
        id: thumb

        required property HyprlandToplevel modelData
        readonly property bool active: modelData === Hypr.activeToplevel

        implicitWidth: root.thumbWidth + Tokens.padding.small * 2
        implicitHeight: frame.height + title.implicitHeight + Tokens.padding.small * 3

        StateLayer {
            radius: Tokens.rounding.medium
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: event => {
                if (event.button === Qt.MiddleButton) {
                    Dock.close(thumb.modelData);
                } else {
                    Dock.focus(thumb.modelData);
                    root.close();
                }
            }
        }

        Rectangle {
            id: frame

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.small
            implicitWidth: root.thumbWidth
            implicitHeight: root.thumbHeight
            radius: Tokens.rounding.small
            color: Colours.palette.m3surfaceContainerHighest
            border.width: thumb.active ? 2 : 0
            border.color: Colours.palette.m3primary

            IconImage {
                anchors.centerIn: parent
                visible: !capture.hasContent
                implicitSize: Math.round(root.thumbHeight * 0.36)
                asynchronous: true
                mipmap: true
                source: Quickshell.iconPath(root.target?.entry?.icon || root.target?.modelData || "", "image-missing")
            }

            ScreencopyView {
                id: capture

                anchors.centerIn: parent
                captureSource: thumb.modelData.wayland ?? null
                constraintSize: Qt.size(root.thumbWidth - 4, root.thumbHeight - 4)
                live: false
                paintCursor: false
            }
        }

        StyledText {
            id: title

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.small
            horizontalAlignment: Text.AlignHCenter
            text: thumb.modelData.title || root.target?.label || ""
            color: thumb.active ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }
    }
}
