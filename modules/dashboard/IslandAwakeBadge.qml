import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.services

Rectangle {
    id: root
    visible: IdleInhibitor.enabled
    readonly property color awakeColour: IslandTheme.palette.awake
    implicitWidth: 28
    implicitHeight: 26
    radius: height / 2
    color: Qt.alpha(awakeColour, 0.14)
    Accessible.name: qsTr("Keep Awake is enabled")
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered
    ToolTip.text: root.Accessible.name
    ToolTip.delay: 600
    MaterialIcon { anchors.centerIn: parent; text: "coffee"; color: parent.awakeColour; fontStyle: Tokens.font.icon.small }
}
