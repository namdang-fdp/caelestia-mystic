pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root
    signal pageRequested(string page)
    readonly property var player: Players.active
    readonly property bool hasMedia: !!player && player.playbackState !== MprisPlaybackState.Stopped
    readonly property bool dragging: positionSlider.pressed
    readonly property int lyricIndex: Lyrics.indexForTime(player?.position ?? 0)
    readonly property string lyric: Lyrics.hasLyrics ? Lyrics.lyrics[lyricIndex] ?? "" : ""
    implicitHeight: 188
    spacing: 12
    readonly property var lyricsBinding: {
        if (hasMedia) Lyrics.setTrack(player.trackArtist, player.trackTitle, player.trackAlbum, player.length);
        else Lyrics.clearTrack();
        return player;
    }
    function duration(value: real): string {
        if (!Number.isFinite(value) || value < 0 || value > 2147483647) return "–:–";
        return `${Math.floor(value / 60)}:${Math.floor(value % 60).toString().padStart(2, "0")}`;
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Rectangle {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60
            radius: 12
            color: IslandTheme.palette.m3surfaceContainerHighest
            clip: true
            Image { anchors.fill: parent; source: Players.getArtUrl(root.player); sourceSize: Qt.size(168,168); fillMode: Image.PreserveAspectCrop; asynchronous: true }
            MaterialIcon { anchors.centerIn: parent; visible: !Players.getArtUrl(root.player); text: "music_note"; fontStyle: Tokens.font.icon.extraLarge; color: IslandTheme.palette.m3primary }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                IslandText { Layout.fillWidth: true; text: root.hasMedia ? root.player.trackTitle || qsTr("Unknown track") : qsTr("Nothing playing"); font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
            }
            IslandText { Layout.fillWidth: true; text: root.hasMedia ? root.player.trackArtist || Players.getIdentity(root.player) : qsTr("Start music in your player"); color: IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight }
            IslandSpectrum { running: !!root.player?.isPlaying && !Audio.muted && Audio.volume > 0; visible: root.hasMedia }
        }
    }
    IslandText {
        Layout.fillWidth: true
        text: root.lyric || (root.hasMedia ? root.player.trackAlbum || Players.getIdentity(root.player) : "")
        color: root.lyric ? IslandTheme.palette.m3primary : IslandTheme.palette.m3outline
        islandFont: Tokens.font.label.medium
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
    RowLayout {
        Layout.fillWidth: true
        IslandText { text: root.player?.positionSupported ? root.duration(root.player.position) : "—"; islandFont: Tokens.font.label.small; color: IslandTheme.palette.m3outline }
        IslandSlider {
            id: positionSlider
            compact: true
            label: qsTr("Playback position")
            Layout.fillWidth: true
            value: root.player ? root.player.position / (root.player.length || 1) : 0
            enabled: !!root.player?.canSeek && !!root.player?.positionSupported && (root.player?.length ?? 0) > 0 && root.player.length < 2147483647
            onMoved: if (root.player?.canSeek) root.player.position = value * root.player.length
        }
        IslandText { text: (root.player?.length ?? 0) > 0 ? root.duration(root.player.length) : "—"; islandFont: Tokens.font.label.small; color: IslandTheme.palette.m3outline }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Item { Layout.fillWidth: true }
        RowLayout {
            spacing: 12
            IslandButton { iconName: "skip_previous"; enabled: !!root.player?.canGoPrevious; Accessible.name: qsTr("Previous track"); onClicked: root.player?.previous() }
            IslandButton { iconName: root.player?.isPlaying ? "pause" : "play_arrow"; accent: true; enabled: !!root.player?.canTogglePlaying; Accessible.name: qsTr("Play or pause"); onClicked: root.player?.togglePlaying() }
            IslandButton { iconName: "skip_next"; enabled: !!root.player?.canGoNext; Accessible.name: qsTr("Next track"); onClicked: root.player?.next() }
        }
        Item { Layout.fillWidth: true }
    }
    Timer { interval: 500; repeat: true; running: root.visible && !!root.player?.isPlaying; onTriggered: root.player?.positionChanged() }
}
