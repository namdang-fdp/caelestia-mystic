pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import "helpers/MusicLogic.js" as Logic

ColumnLayout {
    id: root
    signal pageRequested(string page)
    readonly property var player: IslandAudio.player ?? (IslandAudio.audible ? null : Players.active)
    readonly property bool hasMedia: !!player && player.playbackState !== MprisPlaybackState.Stopped
    // Without MPRIS duration metadata, Quickshell's length follows position.
    readonly property bool hasTimeline: !!player?.lengthSupported && !!player?.positionSupported && Number.isFinite(player.length) && player.length > 0 && player.length < 2147483647
    readonly property bool dragging: positionSlider.pressed
    readonly property int lyricIndex: Lyrics.indexForTime(player?.position ?? 0)
    readonly property string lyric: Lyrics.hasLyrics ? Lyrics.lyrics[lyricIndex] ?? "" : ""
    readonly property var extras: Logic.extras(IslandTools.musicExtras)
    property bool customizing
    implicitHeight: 150 + (lyricText.visible ? 26 : 0) + 44 + (customizing ? 34 : 0)
    spacing: 10
    readonly property var lyricsBinding: {
        if (hasMedia) Lyrics.setTrack(player.trackArtist, player.trackTitle, player.trackAlbum, player.length);
        else Lyrics.clearTrack();
        return player;
    }
    function duration(value: real): string {
        if (!Number.isFinite(value) || value < 0 || value > 2147483647) return "–:–";
        return `${Math.floor(value / 60)}:${Math.floor(value % 60).toString().padStart(2, "0")}`;
    }
    // Compact artwork and metadata, with the live spectrum at the trailing edge.
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        spacing: 12
        ClippingRectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: 10
            color: IslandTheme.palette.m3surfaceContainerHighest
            Image {
                anchors.fill: parent
                source: Players.getArtUrl(root.player)
                sourceSize: Qt.size(168, 168)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            MaterialIcon {
                anchors.centerIn: parent
                visible: !Players.getArtUrl(root.player)
                text: "music_note"
                fontStyle: Tokens.font.icon.extraLarge
                color: IslandTheme.palette.m3onSurfaceVariant
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            IslandText {
                Layout.fillWidth: true
                text: root.hasMedia ? root.player.trackTitle || qsTr("Unknown track") : IslandAudio.audible ? IslandAudio.label : qsTr("Nothing playing")
                font.pixelSize: 14
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            IslandText {
                Layout.fillWidth: true
                text: root.hasMedia ? root.player.trackArtist || Players.getIdentity(root.player) : IslandAudio.audible ? qsTr("Playing audio") : qsTr("Start music in your player")
                font.pixelSize: 13
                color: IslandTheme.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }
        IslandSpectrum {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            scale: 0.65
            opacity: 0.65
            running: IslandAudio.audible
            visible: root.hasMedia || IslandAudio.audible
        }
    }
    IslandText {
        id: lyricText
        Layout.fillWidth: true
        visible: !!root.lyric
        text: root.lyric
        color: IslandTheme.palette.m3onSurfaceVariant
        islandFont: Tokens.font.label.medium
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 24
        spacing: 8
        IslandText {
            text: root.player?.positionSupported ? root.duration(root.player.position) : "—"
            font.pixelSize: 10
            color: IslandTheme.palette.m3onSurfaceVariant
        }
        IslandSlider {
            id: positionSlider
            compact: true
            label: qsTr("Playback position")
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            leftPadding: 0
            rightPadding: 0
            value: root.hasTimeline ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
            enabled: root.hasTimeline && !!root.player?.canSeek
            onMoved: if (root.player?.canSeek) root.player.position = value * root.player.length
            // Keep a generous seek target around the thin visual track.
            background: Rectangle {
                x: positionSlider.leftPadding
                y: (positionSlider.height - height) / 2
                width: positionSlider.availableWidth
                height: 4
                radius: 2
                color: IslandTheme.palette.handle
                border.width: positionSlider.activeFocus ? 1 : 0
                border.color: IslandTheme.palette.focus
                Rectangle {
                    width: parent.width * positionSlider.visualPosition
                    height: parent.height
                    radius: parent.radius
                    color: IslandTheme.palette.m3secondary
                    opacity: positionSlider.enabled ? 1 : 0.4
                }
            }
        }
        IslandText {
            text: root.hasTimeline ? "−" + root.duration(Math.max(0, root.player.length - root.player.position)) : "—"
            font.pixelSize: 10
            color: IslandTheme.palette.m3onSurfaceVariant
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        spacing: 16
        Item { Layout.fillWidth: true }
        MediaButton {
            iconName: "fast_rewind"
            enabled: !!root.player?.canGoPrevious
            Accessible.name: qsTr("Previous track")
            onClicked: root.player?.previous()
        }
        MediaButton {
            iconName: root.player?.isPlaying ? "pause" : "play_arrow"
            iconSize: 40
            enabled: !!root.player?.canTogglePlaying
            Accessible.name: qsTr("Play or pause")
            onClicked: root.player?.togglePlaying()
        }
        MediaButton {
            iconName: "fast_forward"
            enabled: !!root.player?.canGoNext
            Accessible.name: qsTr("Next track")
            onClicked: root.player?.next()
        }
        Item { Layout.fillWidth: true }
    }
    // Extra buttons the user chose, plus the fullscreen show and desktop lyrics.
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Item { Layout.fillWidth: true }
        Repeater {
            model: root.extras
            IslandButton {
                id: extra
                required property string modelData
                readonly property bool toggled: modelData === "shuffle" ? !!root.player?.shuffle : modelData === "loop" ? Number(root.player?.loopState ?? 0) > 0 : false
                iconName: modelData === "loop" ? Logic.loopIcon(root.player?.loopState ?? 0) : Logic.EXTRA_INFO[modelData].icon
                checked: toggled
                implicitHeight: 32; implicitWidth: 36; leftPadding: 6; rightPadding: 6
                enabled: !!root.player && (modelData === "shuffle" ? root.player.shuffleSupported : modelData === "loop" ? root.player.loopSupported : root.player.canSeek)
                Accessible.name: qsTr(Logic.EXTRA_INFO[modelData].label)
                onClicked: {
                    const p = root.player;
                    if (!p) return;
                    if (modelData === "shuffle") p.shuffle = !p.shuffle;
                    else if (modelData === "loop") p.loopState = Logic.nextLoop(p.loopState);
                    else p.position = Logic.seekTarget(p.position, p.length, modelData === "back15" ? -15 : 15);
                }
            }
        }
        IslandButton { iconName: "slideshow"; implicitHeight: 32; implicitWidth: 36; leftPadding: 6; rightPadding: 6; enabled: root.hasMedia; Accessible.name: qsTr("Open music show"); onClicked: MusicShow.toggleShow() }
        IslandButton { iconName: "lyrics"; checked: MusicShow.desktopLyrics; implicitHeight: 32; implicitWidth: 36; leftPadding: 6; rightPadding: 6; Accessible.name: qsTr("Lyrics on the desktop"); onClicked: MusicShow.toggleLyrics() }
        IslandButton { iconName: "tune"; checked: root.customizing; implicitHeight: 32; implicitWidth: 36; leftPadding: 6; rightPadding: 6; Accessible.name: qsTr("Choose buttons"); onClicked: root.customizing = !root.customizing }
        Item { Layout.fillWidth: true }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: root.customizing
        spacing: 6
        Item { Layout.fillWidth: true }
        Repeater {
            model: Logic.EXTRAS
            IslandButton {
                required property string modelData
                text: qsTr(Logic.EXTRA_INFO[modelData].label); iconName: Logic.EXTRA_INFO[modelData].icon
                checked: root.extras.includes(modelData)
                implicitHeight: 28; leftPadding: 8; rightPadding: 8
                onClicked: IslandTools.toggleMusicExtra(modelData)
            }
        }
        Item { Layout.fillWidth: true }
    }
    component MediaButton: IslandButton {
        id: control
        property int iconSize: 30
        implicitWidth: 48
        implicitHeight: 50
        leftPadding: 0
        rightPadding: 0
        contentItem: MaterialIcon {
            text: control.iconName
            fontStyle: Tokens.font.icon.size(control.iconSize * 0.75).build()
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: IslandTheme.palette.m3secondary
            opacity: control.enabled ? 1 : 0.3
        }
    }
    Timer { interval: 500; repeat: true; running: root.visible && !!root.player?.isPlaying; onTriggered: root.player?.positionChanged() }
}
