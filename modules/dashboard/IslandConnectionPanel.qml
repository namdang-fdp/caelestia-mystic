pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.services

Item {
    id: root
    required property string section
    signal closeRequested
    readonly property alias hovered: hover.hovered
    implicitHeight: connections.implicitHeight + 32
    RectangularShadow { anchors.fill: surface; radius: surface.radius; blur: 24; offset.y: 6; color: "#80000000" }
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 22
        gradient: Gradient { GradientStop { position: 0; color: "#1d2025" } GradientStop { position: 1; color: "#15171b" } }
        border.width: 1
        border.color: "#20ffffff"
    }
    HoverHandler { id: hover }
    IslandConnectionsView {
        id: connections
        anchors.fill: parent
        anchors.margins: 16
        section: root.section
        onCloseRequested: root.closeRequested()
    }
}
