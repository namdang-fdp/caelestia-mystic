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
    // Dragging a pin off the dock shows a removal hint instead of the name
    readonly property bool removing: dock.dragRemoving
    readonly property bool dragging: dock.dragging
    property bool showRemove
    readonly property bool active: removing || (DockConfig.showLabels && hoveredItem !== null && !dock.menuOpen && !dock.previewOpen && !dock.dragging)

    onHoveredItemChanged: {
        if (hoveredItem && !dock.dragging) {
            item = hoveredItem;
            showRemove = false;
        }
    }
    onDraggingChanged: {
        if (!dragging && hoveredItem) {
            item = hoveredItem;
            showRemove = false;
        }
    }
    onRemovingChanged: {
        if (removing) {
            item = dock.dragItem;
            showRemove = true;
        }
    }

    x: item?.parent ? item.parent.x + item.x + item.shiftX + item.dragX + item.width / 2 - width / 2 : 0
    y: item?.parent ? item.parent.y + item.y + item.height - dock.pad - dock.iconSize * item.zoom - item.bounceY + item.dragY - height - 10 : 0

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
        text: root.showRemove ? qsTr("Remove") : root.item?.label ?? ""
        font: Tokens.font.body.small
    }
}
