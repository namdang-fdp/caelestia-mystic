pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.services

Item {
    id: root
    property real radius: height / 2
    property bool critical
    readonly property real ear: Math.max(0, Math.min(radius * .7, height - radius, 22))
    readonly property real corner: Math.min(radius, width / 2, height)

    RectangularShadow {
        anchors.fill: parent
        radius: root.radius
        blur: 34
        spread: -12
        offset.y: 14
        color: Qt.alpha("black", IslandTools.glass ? .3 : .9)
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: IslandTools.glass ? IslandTheme.palette.glass : IslandTheme.palette.m3surfaceContainer
            strokeColor: root.critical ? Qt.alpha(IslandTheme.palette.m3error, .55) : IslandTools.glass ? "#2effffff" : "transparent"
            strokeWidth: root.critical || IslandTools.glass ? 1 : 0
            startX: -root.ear; startY: 0
            PathLine { x: root.width + root.ear; y: 0 }
            PathArc { x: root.width; y: root.ear; radiusX: root.ear; radiusY: root.ear; direction: PathArc.Counterclockwise }
            PathLine { x: root.width; y: root.height - root.corner }
            PathArc { x: root.width - root.corner; y: root.height; radiusX: root.corner; radiusY: root.corner }
            PathLine { x: root.corner; y: root.height }
            PathArc { x: 0; y: root.height - root.corner; radiusX: root.corner; radiusY: root.corner }
            PathLine { x: 0; y: root.ear }
            PathArc { x: -root.ear; y: 0; radiusX: root.ear; radiusY: root.ear; direction: PathArc.Counterclockwise }
        }
    }
}
