import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root
    readonly property bool hasMedia: !!Players.active && Players.active.playbackState !== MprisPlaybackState.Stopped
    property bool genericAudio
    signal openRequested
    width: 344
    spacing: 10
    IslandText {
        Layout.fillWidth: true
        text: root.hasMedia ? Players.active.trackTitle || Players.getIdentity(Players.active) : root.genericAudio ? qsTr("System audio") : Time.timeStr
        islandFont: Tokens.font.title.medium
        elide: Text.ElideRight
    }
    IslandText {
        Layout.fillWidth: true
        text: root.hasMedia ? Players.active.trackArtist || Players.getIdentity(Players.active) : root.genericAudio ? Audio.sink?.description ?? qsTr("Audio output") : Time.format("dddd, dd MMMM yyyy")
        color: IslandTheme.palette.m3onSurfaceVariant
        elide: Text.ElideRight
    }
    RowLayout {
        spacing: 8
        IslandSpectrum {
            visible: root.hasMedia || root.genericAudio
            Layout.alignment: Qt.AlignVCenter
            running: (root.hasMedia ? !!Players.active?.isPlaying : root.genericAudio) && !Audio.muted && Audio.volume > 0
        }
        IconButton {
            visible: root.hasMedia
            icon: "skip_previous"
            isRound: true
            disabled: !Players.active?.canGoPrevious
            onClicked: Players.active?.previous()
        }
        IconButton {
            visible: root.hasMedia
            icon: Players.active?.isPlaying ? "pause" : "play_arrow"
            isRound: true
            disabled: !Players.active?.canTogglePlaying
            onClicked: Players.active?.togglePlaying()
        }
        IconButton {
            visible: root.hasMedia
            icon: "skip_next"
            isRound: true
            disabled: !Players.active?.canGoNext
            onClicked: Players.active?.next()
        }
        Item { Layout.fillWidth: true }
        TextButton {
            text: qsTr("Open panels")
            isRound: true
            onClicked: root.openRequested()
        }
    }
}
