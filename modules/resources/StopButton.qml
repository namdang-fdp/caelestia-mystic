import QtQuick
import qs.services

// Destructive two-step button: "Stop" then "Stop?" (armed for a few seconds), then it confirms.
Rectangle {
    id: root

    property string key
    property string label: "Stop"
    signal confirmed

    readonly property bool armed: ResourcesActions.armed !== null && ResourcesActions.armed.key === key

    implicitWidth: text.implicitWidth + 16
    implicitHeight: 22
    radius: ResourcesTheme.radiusControl
    color: armed ? ResourcesTheme.hot : (area.containsMouse ? ResourcesTheme.separator : ResourcesTheme.track)
    opacity: ResourcesActions.busy ? 0.5 : 1

    Text {
        id: text
        anchors.centerIn: parent
        text: root.armed ? root.label + "?" : root.label
        color: root.armed ? "#FFFFFF" : ResourcesTheme.hot
        font.family: ResourcesTheme.uiFont
        font.pixelSize: 11
        font.weight: Font.Medium
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !ResourcesActions.busy
        onClicked: if (ResourcesActions.click(root.key))
            root.confirmed()
    }
}
