pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

StyledWindow {
    id: root

    required property var controller
    required property string screenName

    readonly property bool requestedOpen: controller.openScreenName === screenName && usable
    readonly property bool usable: screen?.name === screenName && !controller.screenHasFullscreen(screenName)
    readonly property real dockWidth: Math.min(820, Math.max(680, width * 0.48), width - 36)
    readonly property real dockHeight: Math.min(420, Math.max(204, contentLoader.item?.implicitHeight ?? 224))
    readonly property real dockBottomMargin: Math.max(14, contentItem.Config.border.thickness + 6)
    readonly property real dockX: (width - dockWidth) / 2
    readonly property real dockY: height - dockBottomMargin - dockHeight

    property bool contentActive
    property bool contentLoaded
    property bool interacting
    property bool forceImmediate
    property real revealProgress

    function finishHide(): void {
        if (requestedOpen)
            return;
        contentActive = false;
        interacting = false;
        controller.setRendering(screenName, false);
    }

    function scheduleHide(): void {
        if (!requestedOpen)
            return;
        if (triggerMouse.containsMouse || dockHover.hovered || interacting) {
            hideDelay.stop();
            return;
        }
        hideDelay.restart();
    }

    onRequestedOpenChanged: {
        if (requestedOpen) {
            hideCleanup.stop();
            hideDelay.stop();
            contentLoaded = true;
            contentActive = true;
            controller.setRendering(screenName, true);
            Qt.callLater(() => {
                if (root.requestedOpen)
                    root.revealProgress = 1;
            });
        } else if (contentActive) {
            const switching = controller.openScreenName.length > 0 && controller.openScreenName !== screenName;
            forceImmediate = switching;
            revealProgress = 0;
            forceImmediate = false;
            if (switching)
                finishHide();
            else
                hideCleanup.restart();
        }
    }

    onUsableChanged: {
        if (!usable)
            controller.requestClose(screenName);
    }

    Component.onDestruction: {
        hideDelay.stop();
        hideCleanup.stop();
        controller.setRendering(screenName, false);
        controller.requestClose(screenName);
    }

    name: "aiusage"
    visible: true
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    mask: usable ? inputRegion : emptyRegion

    Region {
        id: emptyRegion
    }

    Region {
        id: inputRegion

        Region {
            x: (root.width - width) / 2
            y: root.height - height
            width: Math.max(120, Math.min(220, root.width * 0.12))
            height: 4
        }

        Region {
            x: root.contentActive ? root.dockX - 8 : 0
            y: root.contentActive ? root.dockY - 4 : 0
            width: root.contentActive ? root.dockWidth + 16 : 0
            height: root.contentActive ? root.dockHeight + 58 : 0
            radius: root.contentActive ? root.contentItem.Tokens.rounding.extraLarge : 0
        }
    }

    Item {
        id: trigger

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.max(120, Math.min(220, root.width * 0.12))
        height: 4

        MouseArea {
            id: triggerMouse

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onContainsMouseChanged: {
                if (containsMouse)
                    root.controller.requestOpen(root.screenName);
                else
                    root.scheduleHide();
            }
        }
    }

    Item {
        id: dock

        x: root.dockX
        y: root.dockY
        width: root.dockWidth
        height: root.dockHeight
        visible: root.contentActive
        opacity: root.revealProgress
        scale: 0.985 + root.revealProgress * 0.015
        transform: Translate {
            y: (1 - root.revealProgress) * 50
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7 * root.revealProgress)
            shadowVerticalOffset: 2
        }

        StyledClippingRect {
            anchors.fill: parent
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surface

            Loader {
                id: contentLoader

                anchors.fill: parent
                active: root.contentLoaded

                sourceComponent: AiUsageContent {
                    service: root.controller.service
                }
            }
        }

        HoverHandler {
            id: dockHover

            onHoveredChanged: {
                if (hovered)
                    hideDelay.stop();
                else
                    root.scheduleHide();
            }
        }
    }

    Behavior on revealProgress {
        enabled: !root.forceImmediate
        Anim {
            type: Anim.StandardLarge
        }
    }

    Timer {
        id: hideDelay

        interval: 480
        onTriggered: {
            if (!triggerMouse.containsMouse && !dockHover.hovered && !root.interacting)
                root.controller.requestClose(root.screenName);
        }
    }

    Timer {
        id: hideCleanup

        interval: Tokens.anim.durations.large + 40
        onTriggered: root.finishHide()
    }
}
