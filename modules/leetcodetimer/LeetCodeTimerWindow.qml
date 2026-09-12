pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services

StyledWindow {
    id: root

    required property LazyLoader loader
    required property var controller

    readonly property real islandWidth: Math.min(610, width - contentItem.Tokens.padding.extraLarge * 2)
    property real islandHeight: Math.min(content.implicitHeight, height - contentItem.Tokens.padding.extraLarge * 2)

    function close(): void {
        if (!loader.closing)
            closeAnimation.start();
    }

    name: "leetcode-timer"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: loader.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    mask: loader.closing ? emptyRegion : islandRegion

    Behavior on islandHeight {
        Anim {
            type: Anim.StandardSmall
        }
    }

    Region {
        id: emptyRegion
    }

    Region {
        id: islandRegion

        x: (root.width - root.islandWidth) / 2
        y: (root.height - root.islandHeight) / 2
        width: root.islandWidth
        height: root.islandHeight
        radius: root.contentItem.Tokens.rounding.extraLarge
    }

    SequentialAnimation {
        id: closeAnimation

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        ParallelAnimation {
            Anim {
                target: island
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }
            Anim {
                target: island
                property: "scale"
                to: 0.97
                type: Anim.FastSpatial
            }
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Component.onCompleted: {
            root.loader.closing = false;
            forceActiveFocus();
            island.opacity = 1;
            island.scale = 1;
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Space && !content.editorActive) {
                LeetCodeTimer.startOrToggle();
                event.accepted = true;
            }
        }

        StyledRect {
            id: island

            anchors.centerIn: parent
            width: root.islandWidth
            height: root.islandHeight
            opacity: 0
            scale: 0.97
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surface
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.46)

            Behavior on opacity {
                Anim {
                    type: Anim.StandardSmall
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.StandardSmall
                }
            }

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                opacity: parent.opacity
                z: -1
                level: 5
            }

            LeetCodeTimerContent {
                id: content

                anchors.fill: parent
                onCloseRequested: root.close()
            }
        }
    }
}
