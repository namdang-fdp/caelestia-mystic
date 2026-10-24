pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import "helpers/DockLogic.js" as Logic

Item {
    id: root

    required property DockWindow dock
    required property string modelData
    required property int index

    readonly property bool isSeparator: Dock.isSeparator(modelData)
    readonly property AiUsage.Provider usage: modelData.startsWith(Dock.usagePrefix) ? AiUsage.provider(modelData.slice(Dock.usagePrefix.length)) : null
    readonly property bool isApp: !isSeparator && !usage
    readonly property DesktopEntry entry: isApp ? Dock.entryFor(modelData) : null
    readonly property list<HyprlandToplevel> windows: isApp ? Dock.windowsFor(modelData, dock.monitor) : []
    readonly property bool running: windows.length > 0
    readonly property bool active: running && windows.some(w => w === Hypr.activeToplevel)
    readonly property bool urgent: windows.some(w => w.urgent)
    readonly property int badge: DockConfig.showBadges && isApp ? Dock.badgeCount(modelData) : 0
    readonly property string label: {
        if (usage) {
            if (!usage.session && !usage.weekly)
                return usage.error || qsTr("%1 usage").arg(usage.name);
            const parts = [usage.name];
            if (usage.session)
                parts.push(qsTr("5h %1%").arg(Math.round(usage.session.usedPercent)));
            if (usage.weekly)
                parts.push(qsTr("Week %1%").arg(Math.round(usage.weekly.usedPercent)));
            return parts.join(" · ");
        }
        return entry?.name || windows[0]?.title || modelData;
    }
    readonly property bool hovered: mouse.containsMouse

    readonly property real zoom: dock.zoomAt(index)
    property real leavingFactor: dock.leaving[modelData] ? 0 : 1
    property real appear: 0
    property real bounceY
    property bool launching

    // Drag to reorder or unpin
    readonly property int pinIndex: isApp ? Dock.pinnedKeys.indexOf(modelData) : -1
    readonly property bool dragged: dock.dragging && dock.dragKey === modelData
    property real shiftX: dock.dragging ? Logic.dragShift(pinIndex, dock.dragFrom, dock.dragRemoving ? dock.dragFrom : dock.dragTo, dock.iconSize + dock.gap) : 0
    property real dragX
    property real dragY
    property real removeHint: dragged && dock.dragRemoving ? 1 : 0
    property real poof
    property point pressPoint
    property bool suppressClick
    property real wheelDelta

    // File drop target
    property real dropBoost: drop.containsDrag ? 1.18 : 1

    function bounceOnce(): void {
        if (DockConfig.bounce && dock.shownState && !bounceAnim.running)
            bounceAnim.start();
    }

    function finishDrag(commit: bool): void {
        const removing = commit && dock.dragRemoving;
        const moved = commit && !removing ? dock.dragTo - dock.dragFrom : 0;
        // Neighbours jump straight to their committed slots instead of animating twice
        dock.instantShift = true;
        if (moved !== 0)
            DockConfig.movePinnedTo(modelData, Dock.pinnedKeys, dock.dragTo);
        dock.endDrag();
        if (removing) {
            poofAnim.restart();
            return;
        }
        dragX -= moved * (dock.iconSize + dock.gap);
        settleAnim.restart();
    }

    function unpin(): void {
        DockConfig.unpin(modelData);
        // Running apps stay on the dock in the running group, so bring the icon back there
        Qt.callLater(() => {
            if (dock.leaving[modelData])
                return;
            dragX = 0;
            dragY = 0;
            unpoofAnim.restart();
        });
    }

    Component.onCompleted: appear = 1

    onHoveredChanged: {
        if (hovered)
            dock.hoveredItem = root;
        else if (dock.hoveredItem === root)
            dock.hoveredItem = null;
    }
    Component.onDestruction: dock.itemDestroyed(root)
    onRunningChanged: if (running) launching = false
    onUrgentChanged: if (urgent && !active) bounceOnce()
    onLaunchingChanged: if (launching) bounceOnce()

    z: dragged || poof > 0 ? 1 : 0
    implicitWidth: (isSeparator ? dock.separatorWidth : dock.iconSize * zoom + dock.gap) * appear * leavingFactor
    implicitHeight: dock.bgHeight
    transform: Translate {
        x: root.shiftX
    }

    Behavior on shiftX {
        enabled: !root.dock.instantShift

        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on removeHint {
        Anim {
            type: Anim.FastEffects
        }
    }

    Behavior on dropBoost {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Binding {
        target: root
        property: "dragX"
        value: root.dock.dragDx
        when: root.dragged
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root
        property: "dragY"
        value: Math.max(-root.dock.dragHeadroom, Math.min(root.dock.pad, root.dock.dragDy))
        when: root.dragged
        restoreMode: Binding.RestoreNone
    }

    Connections {
        function onShownStateChanged(): void {
            // Hold the urgent bounce while the dock is out of sight
            if (!root.dock.shownState) {
                if (bounceAnim.running)
                    bounceAnim.pause();
            } else if (bounceAnim.paused) {
                bounceAnim.resume();
            } else if (root.launching || (root.urgent && !root.active)) {
                root.bounceOnce();
            }
        }

        target: root.dock
    }

    ParallelAnimation {
        id: settleAnim

        Anim {
            target: root
            property: "dragX"
            to: 0
            type: Anim.DefaultSpatial
        }
        Anim {
            target: root
            property: "dragY"
            to: 0
            type: Anim.DefaultSpatial
        }
    }

    // Puff out of existence when dragged off the dock
    SequentialAnimation {
        id: poofAnim

        Anim {
            target: root
            property: "poof"
            to: 1
            type: Anim.FastEffects
        }
        ScriptAction {
            script: root.unpin()
        }
    }

    Anim {
        id: unpoofAnim

        target: root
        property: "poof"
        to: 0
        type: Anim.DefaultSpatial
    }

    Behavior on appear {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on leavingFactor {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Timer {
        // Give up on the launch animation if the app never maps a window
        running: root.launching
        interval: 8000
        onTriggered: root.launching = false
    }

    SequentialAnimation {
        id: bounceAnim

        loops: 1
        onFinished: {
            if (root.dock.shownState && (root.launching || (root.urgent && !root.active)))
                start();
        }

        NumberAnimation {
            target: root
            property: "bounceY"
            to: root.dock.bounceHeight
            duration: 260
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "bounceY"
            to: 0
            duration: 260
            easing.type: Easing.InQuad
        }
        PauseAnimation {
            duration: 60
        }
    }

    // Separator
    Rectangle {
        visible: root.isSeparator
        anchors.centerIn: parent
        implicitWidth: 1
        implicitHeight: root.dock.iconSize * 0.72
        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.8)
        opacity: root.appear * root.leavingFactor
    }

    // Icon, rendered at the magnified size and scaled down so it stays sharp
    Item {
        id: icon

        readonly property real fullSize: root.dock.iconSize * root.dock.maxZoom

        visible: !root.isSeparator
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.dock.pad + root.bounceY
        implicitWidth: fullSize
        implicitHeight: fullSize
        transformOrigin: Item.Bottom
        scale: root.zoom / root.dock.maxZoom * root.appear * root.leavingFactor * root.dropBoost * (1 + root.poof * 0.5) * (1 - root.removeHint * 0.08)
        opacity: (1 - root.poof) * (1 - root.removeHint * 0.45)
        transform: Translate {
            x: root.dragX
            y: root.dragY
        }

        Loader {
            anchors.fill: parent
            active: !!root.usage
            sourceComponent: UsageTile {
                provider: root.usage
                pressed: mouse.pressed
            }
        }

        IconImage {
            anchors.fill: parent
            visible: root.isApp
            asynchronous: true
            mipmap: true
            source: root.isApp ? Quickshell.iconPath(root.entry?.icon || root.modelData, "image-missing") : ""

            layer.enabled: mouse.pressed
            layer.effect: MultiEffect {
                brightness: -0.3
            }
        }

        DockBadge {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -parent.width * 0.06
            anchors.topMargin: -parent.height * 0.06
            count: root.badge
            baseSize: parent.width * 0.36
        }
    }

    // Running indicator
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(2, (root.dock.pad - height) / 2)

        visible: root.isApp && DockConfig.showIndicators
        implicitWidth: 4
        implicitHeight: 4
        radius: 2
        color: Colours.palette.m3onSurface
        opacity: root.running ? (root.active ? 0.95 : 0.5) * root.leavingFactor * (1 - root.poof) : 0
        scale: root.running ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        anchors.topMargin: -(icon.height * icon.scale - root.dock.iconSize) - root.bounceY
        enabled: !root.isSeparator && root.poof === 0
        hoverEnabled: true
        preventStealing: root.dragged
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: root.dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onPressed: event => {
            root.pressPoint = mouse.mapToItem(null, event.x, event.y);
            root.suppressClick = false;
            root.dock.closePreview();
        }

        onPositionChanged: event => {
            if (!pressed || !(event.buttons & Qt.LeftButton))
                return;
            const p = mouse.mapToItem(null, event.x, event.y);
            const dx = p.x - root.pressPoint.x;
            const dy = p.y - root.pressPoint.y;
            if (!root.dragged) {
                if (root.pinIndex < 0 || root.dock.dragging || root.dock.leaving[root.modelData] || Math.hypot(dx, dy) < 8)
                    return;
                settleAnim.stop();
                root.suppressClick = true;
                root.dock.beginDrag(root);
            }
            root.dock.dragDx = dx;
            root.dock.dragDy = dy;
        }

        onReleased: if (root.dragged) root.finishDrag(true)
        onCanceled: if (root.dragged) root.finishDrag(false)

        onWheel: wheel => {
            if (!root.running) {
                wheel.accepted = false;
                return;
            }
            root.wheelDelta += wheel.angleDelta.y || -wheel.angleDelta.x;
            while (Math.abs(root.wheelDelta) >= 120) {
                const step = root.wheelDelta > 0 ? -1 : 1;
                root.wheelDelta += step * 120;
                root.dock.closePreview();
                Dock.cycle(root.windows, step);
            }
        }

        onClicked: event => {
            if (root.suppressClick)
                return;
            if (root.usage) {
                if (event.button === Qt.MiddleButton)
                    root.usage.refresh(true);
                else
                    root.dock.openUsage(root);
            } else if (event.button === Qt.RightButton) {
                root.dock.openMenu(root);
            } else if (event.button === Qt.MiddleButton) {
                if (Dock.launch(root.modelData))
                    root.launching = !root.running;
            } else if (Dock.activate(root.modelData, root.dock.monitor)) {
                root.launching = true;
            }
        }
    }

    DropArea {
        id: drop

        anchors.fill: mouse
        enabled: root.isApp && !!root.entry && !root.dock.dragging

        onEntered: drag => {
            if (!drag.hasUrls) {
                drag.accepted = false;
                return;
            }
            drag.accept(Qt.CopyAction);
            root.dock.dropItem = root;
        }
        onExited: if (root.dock.dropItem === root) root.dock.dropItem = null
        onDropped: event => {
            if (root.dock.dropItem === root)
                root.dock.dropItem = null;
            if (!event.hasUrls || !Dock.openWith(root.modelData, event.urls.map(u => u.toString())))
                return;
            event.accept(Qt.CopyAction);
            if (!root.running)
                root.launching = true;
        }
    }
}
