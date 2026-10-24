pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import Caelestia.Config
import qs.services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property alias unlocking: unlockAnim.running

    contentItem.Config.screen: screen?.name ?? ""
    contentItem.Tokens.screen: screen?.name ?? ""

    color: "black"

    Connections {
        function onUnlock(): void {
            unlockAnim.start();
        }

        target: root.lock
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            NumberAnimation { target: view; property: "opacity"; to: 0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: view; property: "scale"; to: 1.04; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: 360; easing.type: Easing.InOutCubic }
        }
        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    ParallelAnimation {
        running: true
        NumberAnimation { target: backdrop; property: "opacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            ParallelAnimation {
                NumberAnimation { target: view; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { target: view; property: "scale"; from: .97; to: 1; duration: 420; easing.type: Easing.OutCubic }
            }
        }
    }

    // Blurred wallpaper under a soft scrim keeps text legible on any image.
    Item {
        id: backdrop

        anchors.fill: parent
        opacity: 0

        Image {
            anchors.fill: parent
            source: Wallpapers.actualCurrent || Wallpapers.fallback
            sourceSize: Qt.size(root.width / 2, root.height / 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: .8
                blurMax: 48
                saturation: .1
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha("black", .28) }
                GradientStop { position: .5; color: Qt.alpha("black", .12) }
                GradientStop { position: 1; color: Qt.alpha("black", .45) }
            }
        }
    }

    LockView {
        id: view

        anchors.fill: parent
        visible: Config.lock.enabled
        opacity: 0
        lock: root
    }
}
