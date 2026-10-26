import QtQuick
import QtQuick.Shapes
import Caelestia.Config
import qs.services

// iOS-style battery: the fill tracks the level, green while charging, red when
// low, white otherwise; a bolt sits beside it while plugged in.
Row {
    id: root
    property real level: 1
    property bool charging
    property bool plugged
    readonly property bool low: !plugged && level < .2
    readonly property color fillColour: charging ? IslandTheme.palette.success : low ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurface
    spacing: 3

    Shape {
        visible: root.plugged
        anchors.verticalCenter: parent.verticalCenter
        width: 7; height: 11
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.charging ? IslandTheme.palette.success : IslandTheme.palette.m3onSurfaceVariant
            strokeColor: "transparent"
            startX: 4.4; startY: 0
            PathLine { x: 0; y: 6.3 }
            PathLine { x: 3; y: 6.3 }
            PathLine { x: 2.4; y: 11 }
            PathLine { x: 7; y: 4.6 }
            PathLine { x: 4; y: 4.6 }
            PathLine { x: 4.4; y: 0 }
        }
    }
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 25; height: 12
        Rectangle {
            id: body
            width: 22; height: 12; radius: 3.5
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(IslandTheme.palette.m3onSurface, .4)
            Rectangle {
                x: 2; y: 2
                height: parent.height - 4
                width: Math.max(2, (parent.width - 4) * Math.max(0, Math.min(1, root.level)))
                radius: 1.8
                color: root.fillColour
                Behavior on width { NumberAnimation { duration: 300 * Tokens.anim.durations.scale; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 * Tokens.anim.durations.scale } }
            }
        }
        Rectangle {
            x: body.width + 1; anchors.verticalCenter: body.verticalCenter
            width: 1.6; height: 4; radius: .8
            color: Qt.alpha(IslandTheme.palette.m3onSurface, .4)
        }
    }
}
