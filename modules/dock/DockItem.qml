pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property DockWindow dock
    required property string modelData
    required property int index

    readonly property bool isSeparator: Dock.isSeparator(modelData)
    readonly property AiUsage.Provider usage: modelData.startsWith(Dock.usagePrefix) ? AiUsage.provider(modelData.slice(Dock.usagePrefix.length)) : null
    readonly property bool isApp: !isSeparator && !usage
    readonly property DesktopEntry entry: isApp ? Dock.entryFor(modelData) : null
    readonly property list<HyprlandToplevel> windows: isApp ? Dock.windowsFor(modelData) : []
    readonly property bool running: windows.length > 0
    readonly property bool active: running && Dock.activeKey === modelData
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
    readonly property alias iconItem: icon

    readonly property real zoom: dock.zoomAt(index)
    property real leavingFactor: dock.leaving[modelData] ? 0 : 1
    property real appear: 0
    property real bounceY
    property bool launching

    function bounceOnce(): void {
        if (DockConfig.bounce && !bounceAnim.running)
            bounceAnim.start();
    }

    Component.onCompleted: appear = 1

    onHoveredChanged: {
        if (hovered)
            dock.hoveredItem = root;
        else if (dock.hoveredItem === root)
            dock.hoveredItem = null;
    }
    Component.onDestruction: if (dock.hoveredItem === root) dock.hoveredItem = null
    onRunningChanged: if (running) launching = false
    onUrgentChanged: if (urgent && !active) bounceOnce()
    onLaunchingChanged: if (launching) bounceOnce()

    implicitWidth: (isSeparator ? dock.separatorWidth : dock.iconSize * zoom + dock.gap) * appear * leavingFactor
    implicitHeight: dock.bgHeight

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
            if (root.launching || (root.urgent && !root.active))
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
        scale: root.zoom / root.dock.maxZoom * root.appear * root.leavingFactor

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
        opacity: root.running ? (root.active ? 0.95 : 0.5) * root.leavingFactor : 0
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
        enabled: !root.isSeparator
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: event => {
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
            } else if (Dock.activate(root.modelData)) {
                root.launching = true;
            }
        }
    }
}
