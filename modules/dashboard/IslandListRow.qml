import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import Caelestia.Config
import qs.components
import qs.services

// Row used by the Wi-Fi and Bluetooth detail pages: tinted icon tile, two text
// lines and an optional trailing slot.
T.Button {
    id: root
    property string iconName
    property string subtitle
    property bool active
    property bool busy
    property bool danger
    default property alias trailing: trailingSlot.data
    implicitHeight: 52
    leftPadding: 8; rightPadding: 10; topPadding: 6; bottomPadding: 6
    focusPolicy: Qt.StrongFocus
    Accessible.name: subtitle ? `${text}, ${subtitle}` : text
    HoverHandler { id: hover; cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    background: Rectangle {
        radius: 14
        color: root.down ? IslandTheme.palette.cardHover : hover.hovered ? IslandTheme.palette.card : "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: IslandTheme.palette.focus
        Behavior on color { ColorAnimation { duration: 120 * Tokens.anim.durations.scale } }
    }
    contentItem: RowLayout {
        spacing: 12
        Rectangle {
            Layout.preferredWidth: 34; Layout.preferredHeight: 34
            radius: 17
            color: root.active ? IslandTheme.palette.m3tertiary : IslandTheme.palette.chip
            Behavior on color { ColorAnimation { duration: 160 * Tokens.anim.durations.scale } }
            MaterialIcon {
                anchors.centerIn: parent
                text: root.iconName
                fill: root.active ? 1 : 0
                color: root.active ? IslandTheme.palette.m3onPrimary : IslandTheme.palette.m3onSurface
                fontStyle: Tokens.font.icon.small
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            IslandText { Layout.fillWidth: true; text: root.text; elide: Text.ElideRight; font.pixelSize: 13; font.weight: root.active ? Font.DemiBold : Font.Medium }
            IslandText { Layout.fillWidth: true; visible: !!root.subtitle; text: root.subtitle; elide: Text.ElideRight; font.pixelSize: 11; color: root.danger ? IslandTheme.palette.m3error : root.active ? IslandTheme.palette.m3tertiary : IslandTheme.palette.m3onSurfaceVariant }
        }
        IslandSpinner { running: root.busy }
        Row { id: trailingSlot; spacing: 6; visible: !root.busy }
    }
}
