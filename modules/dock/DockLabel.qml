import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// App name tooltip shown above the hovered icon
StyledRect {
    id: root

    required property DockWindow dock
    property DockItem item

    readonly property DockItem hoveredItem: dock.hoveredItem
    readonly property bool active: DockConfig.showLabels && hoveredItem !== null && !dock.menuOpen

    onHoveredItemChanged: if (hoveredItem) item = hoveredItem

    x: item ? item.parent.x + item.x + item.width / 2 - width / 2 : 0
    y: item ? item.parent.y + item.y + item.height - dock.pad - dock.iconSize * item.zoom - item.bounceY - height - 10 : 0

    implicitWidth: text.implicitWidth + Tokens.padding.large * 2
    implicitHeight: text.implicitHeight + Tokens.padding.small * 2
    radius: Tokens.rounding.full
    color: Colours.tPalette.m3surface
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.6 : 0.45)

    opacity: active ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        Anim {
            type: Anim.FastEffects
        }
    }

    StyledText {
        id: text

        anchors.centerIn: parent
        text: root.item?.label ?? ""
        font: Tokens.font.body.small
    }
}
