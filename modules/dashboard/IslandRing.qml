import QtQuick
import QtQuick.Shapes
import qs.services

// Small progress ring for live activities in the compact pill.
Shape {
    id: root
    property real progress
    property color colour: IslandTheme.palette.m3tertiary
    readonly property real stroke: Math.max(2, width / 8)
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: IslandTheme.palette.chip; strokeWidth: root.stroke; fillColor: "transparent"
        PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width / 2 - root.stroke / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
        strokeColor: root.colour; strokeWidth: root.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.width / 2 - root.stroke / 2; radiusY: radiusX; startAngle: -90; sweepAngle: 360 * Math.max(0, Math.min(1, root.progress)) }
    }
}
