pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property var bar

    readonly property bool active: Pomodoro.hasActiveSession
    readonly property color colour: {
        switch (Pomodoro.phase) {
        case "shortBreak":
            return Colours.palette.m3tertiary;
        case "longBreak":
            return Colours.palette.m3secondary;
        case "focus":
        default:
            return Colours.palette.m3primary;
        }
    }

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.small * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, active ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    StateLayer {
        anchors.fill: parent
        radius: root.radius
        onClicked: {
            if (root.bar.popouts.hasCurrent && root.bar.popouts.currentName === "pomodoro") {
                root.bar.popouts.hasCurrent = false;
            } else {
                root.bar.popouts.currentName = "pomodoro";
                root.bar.popouts.currentCenter = Qt.binding(() => root.mapToItem(root.bar, 0, root.implicitHeight / 2).y);
                root.bar.popouts.hasCurrent = true;
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: 2

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "🍅"
            font.pointSize: 13
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.active
            text: Pomodoro.formattedTime
            font: Tokens.font.label.builders.small.scale(0.85).weight(Font.Medium).build()
            color: root.colour
            opacity: Pomodoro.paused ? 0.6 : 1.0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
