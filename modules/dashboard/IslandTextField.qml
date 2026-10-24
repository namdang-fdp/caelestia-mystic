import QtQuick
import QtQuick.Templates as T
import Caelestia.Config
import qs.services

T.TextField {
    id: root
    implicitWidth: 200
    implicitHeight: 38
    leftPadding: 14; rightPadding: 14
    color: IslandTheme.palette.m3onSurface
    placeholderTextColor: IslandTheme.palette.m3outline
    selectionColor: IslandTheme.palette.m3tertiary
    selectedTextColor: IslandTheme.palette.m3onPrimary
    font.family: IslandTheme.fontFamily
    font.pixelSize: 13
    verticalAlignment: TextInput.AlignVCenter
    background: Rectangle {
        radius: height / 2
        color: IslandTheme.palette.card
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? IslandTheme.palette.focus : IslandTheme.palette.cardBorder
        Behavior on border.color { ColorAnimation { duration: 120 * Tokens.anim.durations.scale } }
    }
}
