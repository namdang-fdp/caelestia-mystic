import QtQuick
import qs.components
import qs.services

// macOS System Settings style icon: a white glyph on a rounded square in a system colour.
Rectangle {
    id: root

    property string icon
    property color tint: ResourcesTheme.blue

    implicitWidth: 22
    implicitHeight: 22
    radius: ResourcesTheme.radiusControl
    color: tint

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        color: "#FFFFFF"
        fill: 0
        fontStyle.pointSize: 11
    }
}
