pragma ComponentBehavior: Bound
import QtQuick
import Caelestia.Config
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.components
import qs.services
import "helpers/ActivityLogic.js" as Logic

Item {
    id: root
    property bool audioVisible
    property bool monitorAudio
    readonly property bool hasMedia: !!Players.active && Players.active.playbackState !== MprisPlaybackState.Stopped
    readonly property bool genericAudio: !hasMedia && sinkLinks.linkGroups.some(g => g.state === PwLinkState.Active)
    readonly property bool hasActivity: hasMedia || genericAudio
    readonly property string activity: WindowUx.resizing ? "resize" : IslandHealth.warning ? "health" : Recorder.running ? "recording" : Audio.sourceMuted ? "muted" : hasActivity ? "media" : "idle"
    readonly property string activityLabel: activity === "resize" ? "RESIZE · Esc to finish" : activity === "health" ? IslandHealth.label : activity === "recording" ? `${Recorder.paused ? qsTr("Paused") : "REC"} ${Logic.clock(Recorder.elapsed)}` : activity === "muted" ? qsTr("Microphone muted") : hasMedia ? Players.active.trackTitle || Players.getIdentity(Players.active) : qsTr("System audio")
    implicitWidth: activity === "idle" ? 190 : Math.max(activity === "media" ? 320 : 240, Math.min(400, row.implicitWidth + 32))
    PwNodeLinkTracker { id: sinkLinks; node: root.monitorAudio ? Audio.sink : null }
    PwObjectTracker { objects: sinkLinks.linkGroups }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10
        IslandText {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.timeStr
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Rectangle { visible: root.activity !== "idle"; width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: "#4a4d52" }
        ClippingRectangle {
            width: 22; height: 22; radius: 6
            visible: root.activity === "media" && !!Players.getArtUrl(Players.active)
            Image { anchors.fill: parent; source: Players.getArtUrl(Players.active); sourceSize: Qt.size(40, 40); fillMode: Image.PreserveAspectCrop }
        }
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.activity !== "idle" && root.activity !== "media"
            text: root.activity === "resize" ? "open_in_full" : root.activity === "health" ? IslandHealth.icon : root.activity === "recording" ? "fiber_manual_record" : "mic_off"
            color: root.activity === "health" || root.activity === "recording" ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }
        IslandText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(200, implicitWidth)
            text: root.activity === "idle" ? Time.format("ddd, MMM d") : root.activityLabel
            color: root.activity === "idle" ? IslandTheme.palette.m3onSurfaceVariant : IslandTheme.palette.m3onSurface
            font.pixelSize: root.activity === "idle" ? 12 : 14
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        IslandSpectrum {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.activity === "media"
            running: root.audioVisible && root.activity === "media" && (root.hasMedia ? Players.active?.isPlaying : root.genericAudio) && !Audio.muted && Audio.volume > 0
            scale: .85
            width: 32; height: 22
        }
    }
}
