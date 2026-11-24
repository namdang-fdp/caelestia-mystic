import QtQuick
import qs.services

// Thin rounded bar, value 0..1.
Rectangle {
    id: root

    property real value
    property color tint: ResourcesTheme.blue

    implicitHeight: 4
    radius: 2
    color: ResourcesTheme.track

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.value))
        height: parent.height
        radius: 2
        color: root.tint

        Behavior on width {
            NumberAnimation {
                duration: 200
            }
        }
    }
}
