pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services
import "helpers/ActivityLogic.js" as Logic

// A second running activity (timer, music, recording) as its own glass bubble that slips out to the left
// of the notch, so two things can be seen at once without crowding one capsule.
Item {
    id: root
    required property Item island
    required property bool available
    readonly property real motionScale: Tokens.anim.durations.scale
    readonly property string kind: island.secondaryActivity
    readonly property bool active: available && island.mode === "compact" && kind !== ""
    readonly property real gap: 8 + island.surfaceEar
    readonly property real targetX: island.x - width - gap
    property real progress: active ? 1 : 0
    property string shownKind

    objectName: "islandActivityBubble"
    width: row.implicitWidth + 28
    height: 36
    x: island.x + (targetX - island.x) * progress
    y: 0
    visible: available && progress > .01
    opacity: Math.min(1, progress * 1.3)
    onKindChanged: if (kind) shownKind = kind
    Behavior on width {
        enabled: root.motionScale > 0
        SpringAnimation { spring: 4; damping: .5; epsilon: .1 }
    }
    Behavior on progress {
        enabled: root.motionScale > 0
        SpringAnimation { spring: 3.6; damping: .55; epsilon: .004 }
    }

    IslandNotch {
        anchors.fill: parent
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Item {
            visible: root.shownKind === "timer"
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter
            IslandRing { anchors.fill: parent; progress: 1 - IslandTimer.progress; colour: IslandTimer.paused ? IslandTheme.palette.yellow : IslandTheme.palette.orange }
        }
        IslandText {
            visible: root.shownKind === "timer"
            anchors.verticalCenter: parent.verticalCenter
            text: IslandTimer.clock
            font.pixelSize: 13
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
        ClippingRectangle {
            visible: root.shownKind === "media" && !!Players.getArtUrl(IslandAudio.player)
            width: 20; height: 20; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            Image { anchors.fill: parent; source: Players.getArtUrl(IslandAudio.player); sourceSize: Qt.size(40, 40); fillMode: Image.PreserveAspectCrop }
        }
        MaterialIcon {
            visible: root.shownKind === "media" && !Players.getArtUrl(IslandAudio.player)
            anchors.verticalCenter: parent.verticalCenter
            text: "music_note"
            color: IslandTheme.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }
        IslandSpectrum {
            visible: root.shownKind === "media"
            anchors.verticalCenter: parent.verticalCenter
            running: root.visible && IslandAudio.audible
            scale: .8
            width: 28; height: 20
        }
        MaterialIcon {
            visible: root.shownKind === "recording"
            anchors.verticalCenter: parent.verticalCenter
            text: "fiber_manual_record"
            color: IslandTheme.palette.m3error
            fontStyle: Tokens.font.icon.small
        }
        IslandText {
            visible: root.shownKind === "recording"
            anchors.verticalCenter: parent.verticalCenter
            text: `${Recorder.paused ? qsTr("Paused") : "REC"} ${Logic.clock(Recorder.elapsed)}`
            font.pixelSize: 13
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
    }
}
