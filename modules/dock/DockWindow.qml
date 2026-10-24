pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import "helpers/DockLogic.js" as Logic

StyledWindow {
    id: root

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property string specialName: monitor?.lastIpcObject.specialWorkspace?.name ?? ""

    // Windows currently visible on this monitor
    readonly property list<HyprlandToplevel> visibleWindows: Hypr.toplevels.values.filter(t => {
        const ws = t.workspace;
        if (!ws || t.lastIpcObject.hidden)
            return false;
        return specialName ? ws.name === specialName : ws.id === monitor?.activeWorkspace?.id;
    })
    readonly property bool hasFullscreen: visibleWindows.some(t => t.lastIpcObject.fullscreen > 1)

    // Geometry
    readonly property real iconSize: DockConfig.iconSize
    readonly property real maxZoom: DockConfig.magnify ? Math.max(1, DockConfig.magnification) : 1
    readonly property real pad: Math.round(iconSize * 0.2)
    readonly property real gap: Math.round(iconSize * 0.14)
    readonly property real separatorWidth: gap * 2 + 1
    readonly property real bgHeight: iconSize + pad * 2
    readonly property real labelSpace: DockConfig.showLabels ? 40 : 0
    readonly property real bounceHeight: Math.round(iconSize * 0.55)
    readonly property real overflow: Math.max(iconSize * (maxZoom - 1) + labelSpace, bounceHeight + labelSpace)
    // Extra room so a dragged icon can be lifted off the dock with its "Remove" hint visible
    readonly property real dragSpace: Math.max(0, Math.ceil(iconSize * 1.2 + 36 - pad - overflow))

    // Items, including ones playing their exit animation
    readonly property list<string> items: Dock.itemsFor(monitor)
    property list<string> shown: []
    property var leaving: ({})

    readonly property list<real> baseCenters: {
        const centers = [];
        let x = 0;
        for (const key of shown) {
            const w = Dock.isSeparator(key) ? separatorWidth : iconSize + gap;
            centers.push(x + w / 2);
            x += w;
        }
        return centers;
    }
    readonly property real baseRowWidth: shown.reduce((w, key) => w + (Dock.isSeparator(key) ? separatorWidth : iconSize + gap), 0)
    readonly property real baseLeft: (width - baseRowWidth) / 2

    property DockItem hoveredItem
    readonly property bool menuOpen: menu.visible || usagePopup.visible
    readonly property bool previewOpen: preview.visible
    // Hovered running app whose window previews should open
    readonly property DockItem previewCandidate: hoveredItem?.isApp && hoveredItem.running && !menuOpen && !dragging ? hoveredItem : null

    // Dragging pinned apps to reorder or unpin them
    property DockItem dragItem
    readonly property bool dragging: dragItem !== null
    readonly property string dragKey: dragItem?.modelData ?? ""
    property int dragFrom: -1
    property real dragDx
    property real dragDy
    property bool instantShift
    readonly property real dragHeadroom: pad + overflow + dragSpace - 36
    readonly property int dragTo: dragging ? Logic.dropIndex(dragFrom, dragDx, iconSize + gap, Dock.pinnedKeys.length) : -1
    readonly property bool dragRemoving: dragging && dragDy < -iconSize * 0.9

    // File drags over the dock
    property DockItem dropItem
    readonly property bool dropping: dropItem !== null || dropArea.containsDrag

    // Magnification
    property real pointerX: -1
    property real magFactor: hover.hovered && DockConfig.magnify && !menuOpen && !dragging ? 1 : 0

    // Visibility
    property bool revealed
    property bool held: hover.hovered || menuOpen || previewOpen || dragging || dropping
    readonly property bool overlapped: {
        const dockW = baseRowWidth + pad * 2;
        const x0 = (screen.width - dockW) / 2;
        const y0 = screen.height - DockConfig.bottomMargin - bgHeight;
        return visibleWindows.some(t => {
            const at = t.lastIpcObject.at;
            const size = t.lastIpcObject.size;
            if (!at || !size)
                return false;
            const wx = at[0] - (monitor?.x ?? 0);
            const wy = at[1] - (monitor?.y ?? 0);
            return wx < x0 + dockW && wx + size[0] > x0 && wy < y0 + bgHeight && wy + size[1] > y0;
        });
    }
    readonly property bool shownState: {
        if (hasFullscreen)
            return false;
        if (held || revealed)
            return true;
        if (DockConfig.hideMode === "never")
            return true;
        if (DockConfig.hideMode === "smart")
            return !overlapped;
        return false;
    }
    property real hideOffset: shownState ? 0 : bgHeight + DockConfig.bottomMargin + 12

    function zoomAt(index: int): real {
        if (magFactor <= 0 || index < 0 || index >= baseCenters.length)
            return 1;
        const d = Math.abs(pointerX - (baseLeft + baseCenters[index]));
        const range = iconSize * 3;
        if (d >= range)
            return 1;
        return 1 + (maxZoom - 1) * magFactor * (Math.cos(Math.PI * d / range) + 1) / 2;
    }

    function sync(): void {
        const next = [...items];
        const nextLeaving = {};
        shown.forEach((key, i) => {
            if (!next.includes(key)) {
                next.splice(Math.min(i, next.length), 0, key);
                nextLeaving[key] = true;
            }
        });
        // Window geometry polling re-evaluates items every second, usually without changes
        const leavingKeys = Object.keys(nextLeaving);
        if (next.length === shown.length && next.every((k, i) => k === shown[i]) && leavingKeys.length === Object.keys(leaving).length && leavingKeys.every(k => leaving[k]))
            return;
        shown = next;
        leaving = nextLeaving;
        if (Object.keys(nextLeaving).length > 0)
            leaveTimer.restart();
    }

    function openUsage(item: DockItem): void {
        // The focus grab closes the popup on press, so a click on its own tile should not reopen it
        if (usagePopup.target === item && (usagePopup.visible || Date.now() - usagePopup.closedAt < 300)) {
            usagePopup.close();
            return;
        }
        usagePopup.visible = false;
        usagePopup.target = item;
        usagePopup.visible = true;
    }

    function openMenu(item: DockItem): void {
        closePreview();
        menu.visible = false;
        menu.target = item;
        menu.visible = true;
    }

    function closePreview(): void {
        previewShowTimer.stop();
        preview.close();
    }

    function beginDrag(item: DockItem): void {
        closePreview();
        menu.close();
        usagePopup.close();
        dragFrom = item.pinIndex;
        dragDx = 0;
        dragDy = 0;
        dragItem = item;
    }

    function endDrag(): void {
        dragItem = null;
        dragFrom = -1;
        // Lets the caller move neighbours without animation for the rest of this event
        Qt.callLater(() => root.instantShift = false);
    }

    function itemDestroyed(item: DockItem): void {
        if (hoveredItem === item)
            hoveredItem = null;
        if (dropItem === item)
            dropItem = null;
        if (dragItem === item)
            endDrag();
        if (menu.target === item)
            menu.close();
        if (preview.target === item)
            preview.close();
        if (usagePopup.target === item)
            usagePopup.close();
    }

    Component.onCompleted: sync()
    onItemsChanged: sync()
    onPreviewCandidateChanged: {
        if (previewCandidate) {
            previewHideTimer.stop();
            // Moving between running apps switches the open preview straight away
            if (preview.visible)
                preview.show(previewCandidate);
            else
                previewShowTimer.restart();
        } else {
            previewShowTimer.stop();
            if (preview.visible)
                previewHideTimer.restart();
        }
    }

    name: "dock"
    WlrLayershell.layer: WlrLayer.Top
    // Setting exclusiveZone forces ExclusionMode.Normal, so a zero zone is used when not reserving space
    exclusiveZone: DockConfig.hideMode === "never" && !hasFullscreen ? bgHeight + DockConfig.bottomMargin : 0

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: DockConfig.bottomMargin + bgHeight + overflow + dragSpace + 8

    mask: Region {
        // Dock body
        Region {
            x: bg.x
            y: bg.y + root.hideOffset
            width: root.shownState ? bg.width : 0
            height: root.shownState ? root.height - y : 0
        }

        // Magnified icons poking above the body, only around the pointer
        Region {
            readonly property real lift: Math.max(0, root.iconSize * (root.maxZoom - 1) * root.magFactor - root.pad) + 6

            x: root.pointerX - root.iconSize * 1.5
            y: bg.y + root.hideOffset - lift
            width: root.shownState && root.magFactor > 0 ? root.iconSize * 3 : 0
            height: lift
        }

        // Whole surface while an icon is dragged so it can leave the dock
        Region {
            width: root.dragging ? root.width : 0
            height: root.dragging ? root.height : 0
        }

        // Bottom edge trigger while hidden
        Region {
            x: root.baseLeft - root.pad
            y: root.height - 2
            width: !root.shownState && !root.hasFullscreen ? root.baseRowWidth + root.pad * 2 : 0
            height: 2
        }
    }

    onHeldChanged: {
        if (held) {
            hideTimer.stop();
        } else if (revealed) {
            hideTimer.restart();
        }
    }

    Behavior on magFactor {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on hideOffset {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Timer {
        id: leaveTimer

        interval: Tokens.anim.durations.expressiveDefaultSpatial
        onTriggered: {
            root.shown = root.shown.filter(k => !root.leaving[k]);
            root.leaving = {};
        }
    }

    Timer {
        id: hideTimer

        interval: 450
        onTriggered: root.revealed = false
    }

    Timer {
        id: previewShowTimer

        interval: 550
        onTriggered: if (root.previewCandidate) preview.show(root.previewCandidate)
    }

    Timer {
        id: previewHideTimer

        // Grace period for moving the pointer from the icon onto the preview
        interval: 300
        onTriggered: if (!root.previewCandidate && !preview.hovered) preview.close()
    }

    Connections {
        function onHoveredChanged(): void {
            if (preview.hovered)
                previewHideTimer.stop();
            else if (!root.previewCandidate)
                previewHideTimer.restart();
        }

        target: preview
    }

    Item {
        id: content

        anchors.fill: parent

        // Reveals a hidden dock when files are dragged to the bottom edge
        DropArea {
            id: dropArea

            anchors.fill: parent
            onEntered: {
                if (!root.shownState)
                    root.revealed = true;
            }
            onDropped: drop => drop.accepted = false
        }

        HoverHandler {
            id: hover

            onPointChanged: if (hovered) root.pointerX = point.position.x
            onHoveredChanged: {
                if (!hovered)
                    return;
                root.pointerX = point.position.x;
                if (!root.shownState)
                    root.revealed = true;
            }
        }

        Item {
            id: body

            anchors.fill: parent
            transform: Translate {
                y: root.hideOffset
            }
            opacity: root.shownState ? 1 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            RectangularShadow {
                anchors.fill: bg
                radius: bg.radius
                blur: 24
                offset.y: 6
                spread: -2
                color: Qt.alpha(Colours.palette.m3shadow, 0.35)
            }

            StyledRect {
                id: bg

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: DockConfig.bottomMargin

                implicitWidth: row.width + root.pad * 2 - root.gap
                implicitHeight: root.bgHeight
                radius: Math.round(root.bgHeight * 0.32)
                color: Colours.tPalette.m3surface
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.6 : 0.45)
            }

            Row {
                id: row

                anchors.horizontalCenter: bg.horizontalCenter
                anchors.bottom: bg.bottom

                Repeater {
                    model: ScriptModel {
                        values: root.shown
                    }

                    DockItem {
                        dock: root
                    }
                }
            }

            DockLabel {
                dock: root
            }
        }
    }

    DockMenu {
        id: menu

        dock: root
    }

    DockUsagePopup {
        id: usagePopup

        dock: root
    }

    DockPreview {
        id: preview

        dock: root
    }
}
