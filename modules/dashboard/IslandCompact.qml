pragma ComponentBehavior: Bound
import QtQuick
import Caelestia.Config
import Caelestia.Services
import Quickshell.Widgets
import qs.components
import qs.services
import "helpers/ActivityLogic.js" as Logic

Item {
    id: root
    property bool audioVisible
    // The companion animates only on the focused screen.
    property bool focusedScreen: true
    // "auto" follows the live activity and shows the companion next to the
    // clock when nothing is happening; "lyrics" and "stats" are opt-in faces.
    property string restingMode: "auto"
    readonly property bool companion: activity === "idle" && restingMode === "auto"
    readonly property var player: IslandAudio.player
    readonly property bool hasMedia: !!player
    readonly property bool genericAudio: !hasMedia && IslandAudio.audible
    readonly property bool hasActivity: hasMedia || genericAudio
    readonly property bool lyricsReady: restingMode === "lyrics" && hasMedia && Lyrics.hasLyrics
    readonly property string lyric: lyricsReady ? Lyrics.lyrics[Lyrics.indexForTime(Players.active?.position ?? 0)] ?? "" : ""
    readonly property bool timerChip: IslandTimer.active && activity === "media"
    readonly property var availableModes: ["auto", ...(hasMedia ? ["lyrics"] : []), "stats"]
    readonly property string activity: WindowUx.resizing ? "resize" : IslandHealth.warning ? "health" : Recorder.running ? "recording" : IslandTimer.active && !hasActivity ? "timer" : Audio.sourceMuted ? "muted" : hasActivity ? "media" : restingMode === "stats" ? "stats" : "idle"
    readonly property string activityLabel: activity === "resize" ? "RESIZE · Esc to finish" : activity === "health" ? IslandHealth.label : activity === "recording" ? `${Recorder.paused ? qsTr("Paused") : "REC"} ${Logic.clock(Recorder.elapsed)}` : activity === "timer" ? `${IslandTimer.paused ? qsTr("Paused") : IslandTimer.label} ${IslandTimer.clock}` : activity === "muted" ? qsTr("Microphone muted") : activity === "stats" ? statsLabel : hasMedia ? lyric || Players.active.trackTitle || Players.getIdentity(Players.active) : qsTr("System audio")
    readonly property string statsLabel: [`CPU ${Math.round(Cpu.percentage * 100)}%`, `RAM ${Math.round(Memory.percentage * 100)}%`, ...(Cpu.temperature > 0 ? [`${Math.round(Cpu.temperature)}°C`] : [])].join("  ·  ")
    implicitWidth: companion ? row.implicitWidth + 36 : activity === "idle" ? 190 : Math.max(activity === "media" ? 320 : 240, Math.min(lyricsReady ? 460 : 400, row.implicitWidth + 32))
    function cycleMode(direction: int): void { restingMode = Logic.nextRestingMode(restingMode, availableModes, direction); }
    function greet(): void { eyes.greet(); }
    onAvailableModesChanged: if (!availableModes.includes(restingMode)) restingMode = "auto"
    // Only the lyrics face needs the track's lyrics; the media page requests them itself.
    onLyricsTrackChanged: if (restingMode === "lyrics" && hasMedia) Lyrics.setTrack(player.trackArtist, player.trackTitle, player.trackAlbum, player.length)
    readonly property string lyricsTrack: restingMode === "lyrics" && hasMedia ? `${player.trackArtist}\n${player.trackTitle}` : ""
    ServiceRef { service: root.activity === "stats" && root.audioVisible ? Cpu : null }
    ServiceRef { service: root.activity === "stats" && root.audioVisible ? Memory : null }
    Timer { interval: 500; repeat: true; running: root.lyricsReady && root.audioVisible && !!root.player?.isPlaying; onTriggered: root.player?.positionChanged() }
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
        IslandEyes {
            id: eyes
            anchors.verticalCenter: parent.verticalCenter
            visible: root.companion
            width: 40; height: 22
            running: root.companion && root.audioVisible
            dozing: IslandIdle.away
            live: root.focusedScreen
            motionScale: Tokens.anim.durations.scale
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
            IslandRing { anchors.fill: parent; progress: 1 - IslandTimer.progress; colour: IslandTimer.paused ? IslandTheme.palette.yellow : IslandTheme.palette.orange }
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
            visible: !root.companion
            anchors.verticalCenter: parent.verticalCenter
            // Reserve space for concurrent badges before eliding the title.
            width: Math.min(implicitWidth, Math.max(0, (root.lyricsReady ? 280 : 200)
                - (root.timerChip ? timerBadge.implicitWidth + row.spacing : 0)
                - (Audio.sourceMuted ? microphoneBadge.implicitWidth + row.spacing : 0)))
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
            id: timerBadge
            visible: root.timerChip
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            IslandRing { width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter; progress: 1 - IslandTimer.progress; colour: IslandTimer.paused ? IslandTheme.palette.yellow : IslandTheme.palette.orange }
            IslandText { anchors.verticalCenter: parent.verticalCenter; text: IslandTimer.clock; font.pixelSize: 12; font.features: { "tnum": 1 }; color: IslandTheme.palette.m3onSurfaceVariant }
        }
        IslandSpectrum {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.activity === "media"
            running: root.audioVisible && root.activity === "media" && IslandAudio.audible
            scale: .85
            width: 32; height: 22
        }
        MaterialIcon {
            id: microphoneBadge
            objectName: "islandMicrophoneBadge"
            anchors.verticalCenter: parent.verticalCenter
            visible: Audio.sourceMuted
            text: "mic_off"
            fontStyle: Tokens.font.icon.small
            color: IslandTheme.palette.m3onSurfaceVariant
            Accessible.role: Accessible.Indicator
            Accessible.name: qsTr("Microphone muted")
        }
        MaterialIcon {
            objectName: "islandCameraBadge"
            anchors.verticalCenter: parent.verticalCenter
            visible: IslandLive.cameraActive
            text: "videocam"
            fontStyle: Tokens.font.icon.small
            color: IslandTheme.palette.success
            Accessible.role: Accessible.Indicator
            Accessible.name: qsTr("Camera in use")
        }
        MaterialIcon {
            objectName: "islandMicActiveBadge"
            anchors.verticalCenter: parent.verticalCenter
            visible: IslandLive.micActive && !Audio.sourceMuted
            text: "mic"
            fontStyle: Tokens.font.icon.small
            color: "#ff9f0a"
            Accessible.role: Accessible.Indicator
            Accessible.name: qsTr("Microphone in use")
        }
    }
}
