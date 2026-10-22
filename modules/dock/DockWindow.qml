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

    // Items, including ones playing their exit animation
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

    // Magnification
    property real pointerX: -1
    property real magFactor: hover.hovered && DockConfig.magnify && !menuOpen ? 1 : 0

    // Visibility
    property bool revealed
    property bool held: hover.hovered || menuOpen
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
        const next = [...Dock.items];
        const nextLeaving = {};
        shown.forEach((key, i) => {
            if (!next.includes(key)) {
                next.splice(Math.min(i, next.length), 0, key);
                nextLeaving[key] = true;
            }
        });
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
        menu.visible = false;
        menu.target = item;
        menu.visible = true;
    }

    Component.onCompleted: sync()

    name: "dock"
    WlrLayershell.layer: WlrLayer.Top
    // Setting exclusiveZone forces ExclusionMode.Normal, so a zero zone is used when not reserving space
    exclusiveZone: DockConfig.hideMode === "never" && !hasFullscreen ? bgHeight + DockConfig.bottomMargin : 0

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: DockConfig.bottomMargin + bgHeight + overflow + 8

    mask: Region {
        // Dock body, extended upwards to cover magnified icons
        Region {
            x: bg.x
            y: bg.y + root.hideOffset - (root.magFactor > 0 ? root.overflow : 0)
            width: root.shownState ? bg.width : 0
            height: root.shownState ? root.height - y : 0
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

    Connections {
        function onItemsChanged(): void {
            root.sync();
        }

        target: Dock
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

    Item {
        id: content

        anchors.fill: parent

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
}
