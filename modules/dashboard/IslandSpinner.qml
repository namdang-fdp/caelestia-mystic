import QtQuick
import Caelestia.Config
import qs.components
import qs.services

MaterialIcon {
    id: root
    property bool running: true
    text: "progress_activity"
    color: IslandTheme.palette.m3onSurfaceVariant
    fontStyle: Tokens.font.icon.small
    visible: running
    RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.running && root.visible }
}
