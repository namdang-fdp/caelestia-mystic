import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Dock tile showing plan usage: outer ring is the 5h session, inner ring the week
Item {
    id: root

    required property AiUsage.Provider provider
    property bool pressed

    readonly property real size: Math.min(width, height)
    readonly property real stroke: size * 0.07
    readonly property real outerRadius: size * 0.36
    readonly property real innerRadius: outerRadius - stroke * 1.75
    readonly property bool hasData: (provider?.limits.length ?? 0) > 0

    opacity: provider?.stale ? 0.6 : 1

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.size * 0.04
        radius: width * 0.24
        color: root.pressed ? Qt.darker(Colours.palette.m3surfaceContainerHigh, 1.3) : Colours.palette.m3surfaceContainerHigh
        border.width: Math.max(1, root.size * 0.012)
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
    }

    Ring {
        radius: root.outerRadius
        percent: root.provider?.session?.usedPercent ?? 0
    }

    Ring {
        radius: root.innerRadius
        percent: root.provider?.weekly?.usedPercent ?? 0
    }

    IconImage {
        anchors.centerIn: parent
        implicitSize: root.size * 0.3
        asynchronous: true
        mipmap: true
        source: Quickshell.iconPath(root.provider?.icon ?? "", "image-missing")
        opacity: root.hasData ? 1 : 0.45
    }

    component Ring: Shape {
        id: ring

        required property real radius
        required property real percent
        property real sweep: 360 * Math.min(100, Math.max(0, percent)) / 100

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        Behavior on sweep {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        ShapePath {
            strokeColor: Qt.alpha(Colours.palette.m3onSurface, 0.14)
            strokeWidth: root.stroke
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: ring.sweep > 0.5 ? AiUsage.severityColour(ring.percent) : "transparent"
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: -90
                sweepAngle: ring.sweep
            }
        }
    }
}
