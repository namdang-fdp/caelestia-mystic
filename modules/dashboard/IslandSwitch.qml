import QtQuick
import QtQuick.Templates as T
import Caelestia.Config
import qs.services

// Display-only switch: the owner flips the backing state in onClicked, so the
// binding on `checked` survives clicks.
T.AbstractButton {
    id: root
    implicitWidth: 38
    implicitHeight: 22
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    background: Rectangle {
        radius: height / 2
        color: root.checked ? IslandTheme.palette.success : IslandTheme.palette.switchOff
        opacity: root.enabled ? 1 : .4
        border.width: root.activeFocus ? 2 : 0
        border.color: IslandTheme.palette.focus
        Behavior on color { ColorAnimation { duration: 160 * Tokens.anim.durations.scale } }
        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            y: 3
            width: parent.height - 6; height: width; radius: width / 2
            color: "white"
            scale: root.down ? .9 : 1
            Behavior on x { NumberAnimation { duration: 200 * Tokens.anim.durations.scale; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 120 * Tokens.anim.durations.scale } }
        }
    }
    contentItem: Item {}
}
