import QtQuick
import qs.services

// macOS-style switch.
Rectangle {
    id: root

    property bool checked
    signal toggled

    implicitWidth: 42
    implicitHeight: 24
    radius: 12
    color: checked ? ResourcesTheme.ok : ResourcesTheme.track

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Rectangle {
        y: 2
        x: root.checked ? parent.width - width - 2 : 2
        width: 20
        height: 20
        radius: 10
        color: "#FFFFFF"

        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
