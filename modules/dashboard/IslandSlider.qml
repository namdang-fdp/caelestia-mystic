import QtQuick
import Caelestia.Config
import QtQuick.Templates as T
import qs.components
import qs.services

T.Slider {
    id: root
    property string iconName
    property string label
    property bool compact: false
    implicitWidth: 180
    implicitHeight: compact ? 6 : 32
    from: 0
    to: 1
    stepSize: 0.01
    wheelEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: label
    background: Rectangle {
        radius: height / 2
        color: "#303236"
        border.width: root.activeFocus ? 2 : 0
        border.color: "#8daeff"
        Rectangle {
            height: parent.height
            width: parent.width * root.visualPosition
            radius: parent.radius
            color: root.enabled ? "#f3f3f5" : "#777a80"
        }
        MaterialIcon {
            visible: !root.compact && !!root.iconName
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconName
            color: root.visualPosition > .14 ? "#26282b" : "#f3f3f5"
            fontStyle: Tokens.font.icon.small
        }
    }
    handle: Item { implicitWidth: 0; implicitHeight: 0 }
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
}
