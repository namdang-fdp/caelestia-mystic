import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import Caelestia.Config
import qs.components
import qs.services

T.Button {
    id: root
    property string iconName
    property bool accent
    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: 36
    leftPadding: 12
    rightPadding: 12
    focusPolicy: Qt.StrongFocus
    Accessible.name: text || iconName
    ToolTip.visible: hovered && !text && !!Accessible.name
    ToolTip.text: Accessible.name
    ToolTip.delay: 600
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    background: Rectangle {
        radius: height / 2
        color: root.accent ? IslandTheme.palette.m3primary : root.checked || root.hovered || root.down ? IslandTheme.palette.m3surfaceContainerHighest : "transparent"
        opacity: root.enabled ? 1 : 0.4
        border.width: root.activeFocus ? 2 : 0
        border.color: IslandTheme.palette.m3secondary
        Behavior on color { ColorAnimation { duration: 140 * Tokens.anim.durations.scale } }
    }
    contentItem: Row {
        spacing: root.iconName && root.text ? 6 : 0
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.iconName
            text: root.iconName
            color: root.accent ? IslandTheme.palette.m3onPrimary : root.checked ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
            opacity: root.enabled ? 1 : 0.4
        }
        IslandText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.accent ? IslandTheme.palette.m3onPrimary : root.checked ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3onSurfaceVariant
            islandFont: Tokens.font.label.medium
            opacity: root.enabled ? 1 : 0.4
        }
    }
}
