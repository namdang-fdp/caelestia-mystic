pragma ComponentBehavior: Bound
import QtQuick
import Caelestia.Config
import Caelestia.Services
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
    // "auto" follows the live activity; "lyrics" and "stats" are opt-in resting faces.
    property string restingMode: "auto"
    readonly property bool hasMedia: !!Players.active && Players.active.playbackState !== MprisPlaybackState.Stopped
    readonly property bool genericAudio: !hasMedia && sinkLinks.linkGroups.some(g => g.state === PwLinkState.Active)
    readonly property bool hasActivity: hasMedia || genericAudio
    readonly property bool lyricsReady: restingMode === "lyrics" && hasMedia && Lyrics.hasLyrics
    readonly property string lyric: lyricsReady ? Lyrics.lyrics[Lyrics.indexForTime(Players.active?.position ?? 0)] ?? "" : ""
    readonly property bool timerChip: IslandTimer.active && activity === "media"
    readonly property var availableModes: ["auto", ...(hasMedia ? ["lyrics"] : []), "stats"]
    readonly property string activity: WindowUx.resizing ? "resize" : IslandHealth.warning ? "health" : Recorder.running ? "recording" : IslandTimer.active && !hasActivity ? "timer" : Audio.sourceMuted ? "muted" : hasActivity ? "media" : restingMode === "stats" ? "stats" : "idle"
    readonly property string activityLabel: activity === "resize" ? "RESIZE · Esc to finish" : activity === "health" ? IslandHealth.label : activity === "recording" ? `${Recorder.paused ? qsTr("Paused") : "REC"} ${Logic.clock(Recorder.elapsed)}` : activity === "timer" ? `${IslandTimer.paused ? qsTr("Paused") : IslandTimer.label} ${IslandTimer.clock}` : activity === "muted" ? qsTr("Microphone muted") : activity === "stats" ? statsLabel : hasMedia ? lyric || Players.active.trackTitle || Players.getIdentity(Players.active) : qsTr("System audio")
    readonly property string statsLabel: [`CPU ${Math.round(Cpu.percentage * 100)}%`, `RAM ${Math.round(Memory.percentage * 100)}%`, ...(Cpu.temperature > 0 ? [`${Math.round(Cpu.temperature)}°C`] : [])].join("  ·  ")
    implicitWidth: activity === "idle" ? 190 : Math.max(activity === "media" ? 320 : 240, Math.min(lyricsReady ? 460 : 400, row.implicitWidth + 32))
    function cycleMode(direction: int): void { restingMode = Logic.nextRestingMode(restingMode, availableModes, direction); }
    onAvailableModesChanged: if (!availableModes.includes(restingMode)) restingMode = "auto"
    // Only the lyrics face needs the track's lyrics; the media page requests them itself.
    onLyricsTrackChanged: if (restingMode === "lyrics" && hasMedia) Lyrics.setTrack(Players.active.trackArtist, Players.active.trackTitle, Players.active.trackAlbum, Players.active.length)
    readonly property string lyricsTrack: restingMode === "lyrics" && hasMedia ? `${Players.active.trackArtist}\n${Players.active.trackTitle}` : ""
    PwNodeLinkTracker { id: sinkLinks; node: root.monitorAudio ? Audio.sink : null }
    PwObjectTracker { objects: sinkLinks.linkGroups }
    ServiceRef { service: root.activity === "stats" && root.audioVisible ? Cpu : null }
    ServiceRef { service: root.activity === "stats" && root.audioVisible ? Memory : null }
    Timer { interval: 500; repeat: true; running: root.lyricsReady && root.audioVisible && !!Players.active?.isPlaying; onTriggered: Players.active?.positionChanged() }
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
        Rectangle { visible: root.activity !== "idle"; width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: IslandTheme.palette.divider }
        ClippingRectangle {
            width: 22; height: 22; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.activity === "media" && !!Players.getArtUrl(Players.active)
            Image { anchors.fill: parent; source: Players.getArtUrl(Players.active); sourceSize: Qt.size(40, 40); fillMode: Image.PreserveAspectCrop }
        }
        Item {
            visible: root.activity === "timer"
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            IslandRing { anchors.fill: parent; progress: 1 - IslandTimer.progress; colour: IslandTimer.paused ? IslandTheme.palette.warning : IslandTheme.palette.m3tertiary }
        }
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !["idle", "media", "timer"].includes(root.activity)
            text: root.activity === "resize" ? "open_in_full" : root.activity === "health" ? IslandHealth.icon : root.activity === "recording" ? "fiber_manual_record" : root.activity === "stats" ? "monitoring" : "mic_off"
            color: root.activity === "health" || root.activity === "recording" ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }
        IslandText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(root.lyricsReady ? 280 : 200, implicitWidth)
            text: root.activity === "idle" ? Time.format("ddd, MMM d") : root.activityLabel
            color: root.activity === "idle" ? IslandTheme.palette.m3onSurfaceVariant : root.lyric ? IslandTheme.palette.m3tertiary : IslandTheme.palette.m3onSurface
            font.pixelSize: root.activity === "idle" || root.activity === "stats" ? 12 : 14
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
            elide: Text.ElideRight
            // Lyric lines cross-fade instead of snapping.
            Behavior on text {
                enabled: root.lyricsReady && root.activity === "media"
                SequentialAnimation {
                    NumberAnimation { target: label; property: "opacity"; to: 0; duration: 90 }
                    PropertyAction {}
                    NumberAnimation { target: label; property: "opacity"; to: 1; duration: 160 }
                }
            }
        }
        Row {
            visible: root.timerChip
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            IslandRing { width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter; progress: 1 - IslandTimer.progress; colour: IslandTimer.paused ? IslandTheme.palette.warning : IslandTheme.palette.m3tertiary }
            IslandText { anchors.verticalCenter: parent.verticalCenter; text: IslandTimer.clock; font.pixelSize: 12; font.features: { "tnum": 1 }; color: IslandTheme.palette.m3onSurfaceVariant }
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
