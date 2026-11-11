pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services
import qs.modules.dashboard
import "../dashboard/helpers/MusicLogic.js" as Logic

// Fullscreen music show (spinning disc, synced lyrics, five themes) and a
// click-through lyric line for the desktop. Both only exist while switched on.
Scope {
    id: root
    readonly property var player: IslandAudio.player ?? Players.active
    readonly property bool hasMedia: !!player && player.playbackState !== MprisPlaybackState.Stopped
    readonly property int lyricIndex: Lyrics.indexForTime(player?.position ?? 0)
    readonly property bool wanted: (MusicShow.show || MusicShow.desktopLyrics) && hasMedia
    readonly property var palette: Logic.theme(MusicShow.theme)
    readonly property string focusedName: Hypr.focusedMonitor?.name ?? ""

    // Lyrics for the current track, only while either view is on.
    readonly property var lyricsBinding: {
        if (wanted) Lyrics.setTrack(player.trackArtist, player.trackTitle, player.trackAlbum, player.length);
        return player;
    }
    Timer { interval: 500; repeat: true; running: root.wanted && !!root.player?.isPlaying; onTriggered: root.player?.positionChanged() }

    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property ShellScreen modelData
            readonly property bool here: modelData.name === root.focusedName || Quickshell.screens.length === 1

            PanelWindow {
                id: show
                screen: perScreen.modelData
                visible: MusicShow.show && perScreen.here
                color: "black"
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "caelestia-musicshow"
                WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                onVisibleChanged: if (visible) stage.forceActiveFocus()

                FocusScope {
                    id: stage
                    anchors.fill: parent
                    Keys.onEscapePressed: MusicShow.show = false
                    Keys.onSpacePressed: root.player?.togglePlaying()
                    Keys.onLeftPressed: root.player?.previous()
                    Keys.onRightPressed: root.player?.next()
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0; color: root.palette.from }
                            GradientStop { position: 1; color: root.palette.to }
                        }
                    }
                    Image {
                        anchors.fill: parent
                        source: Players.getArtUrl(root.player)
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        opacity: .09
                        smooth: true
                    }
                    RowLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 160, 1200)
                        spacing: 90
                        // Disc
                        Item {
                            Layout.preferredWidth: Math.min(stage.height * .5, 460)
                            Layout.preferredHeight: Layout.preferredWidth
                            Rectangle { anchors.fill: parent; radius: width / 2; color: "#0c0c0e"; border.width: 2; border.color: "#26ffffff" }
                            ClippingRectangle {
                                id: disc
                                anchors.centerIn: parent
                                width: parent.width * .74; height: width; radius: width / 2
                                color: "#1c1c1e"
                                Image { anchors.fill: parent; source: Players.getArtUrl(root.player); sourceSize: Qt.size(600, 600); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                RotationAnimator on rotation { from: 0; to: 360; duration: 28000; loops: Animation.Infinite; running: show.visible && !!root.player?.isPlaying }
                            }
                            Rectangle { anchors.centerIn: parent; width: parent.width * .08; height: width; radius: width / 2; color: "#000000"; border.width: 2; border.color: "#33ffffff" }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            IslandText { Layout.fillWidth: true; text: root.player?.trackTitle || qsTr("Unknown track"); color: "white"; font.pixelSize: 40; font.weight: Font.Bold; elide: Text.ElideRight }
                            IslandText { Layout.fillWidth: true; text: root.player?.trackArtist || Players.getIdentity(root.player); color: "#b3ffffff"; font.pixelSize: 20; elide: Text.ElideRight }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 24
                                spacing: 10
                                Repeater {
                                    model: Logic.lyricWindow(Lyrics.lyrics, root.lyricIndex, 1, 3)
                                    IslandText {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        color: modelData.offset === 0 ? root.palette.accent : "white"
                                        opacity: modelData.offset === 0 ? 1 : modelData.offset < 0 ? .35 : Math.max(.3, .75 - modelData.offset * .2)
                                        font.pixelSize: modelData.offset === 0 ? 30 : 22
                                        font.weight: modelData.offset === 0 ? Font.Bold : Font.Medium
                                        elide: Text.ElideRight
                                    }
                                }
                                IslandText { visible: !Lyrics.hasLyrics; text: qsTr("No lyrics for this track"); color: "#80ffffff"; font.pixelSize: 18 }
                            }
                            Item { Layout.preferredHeight: 18 }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 4; radius: 2; color: "#33ffffff"
                                Rectangle { width: parent.width * (root.player && root.player.length > 0 ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0); height: parent.height; radius: 2; color: root.palette.accent }
                            }
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 8
                                spacing: 28
                                ShowButton { iconName: "skip_previous"; onClicked: root.player?.previous() }
                                ShowButton { iconName: root.player?.isPlaying ? "pause_circle" : "play_circle"; big: true; onClicked: root.player?.togglePlaying() }
                                ShowButton { iconName: "skip_next"; onClicked: root.player?.next() }
                            }
                        }
                    }
                    RowLayout {
                        anchors { top: parent.top; right: parent.right; margins: 28 }
                        spacing: 10
                        ShowButton { iconName: "palette"; onClicked: MusicShow.nextTheme() }
                        ShowButton { iconName: "close"; onClicked: MusicShow.show = false }
                    }
                }
            }

            PanelWindow {
                id: floating
                screen: perScreen.modelData
                visible: MusicShow.desktopLyrics && perScreen.here && root.hasMedia && !!root.player?.isPlaying
                color: "transparent"
                anchors { bottom: true; left: true; right: true }
                implicitHeight: 120
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "caelestia-desktop-lyrics"
                mask: Region {}
                IslandText {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 56 }
                    width: Math.min(parent.width - 80, 1100)
                    horizontalAlignment: Text.AlignHCenter
                    text: Lyrics.hasLyrics ? Lyrics.lyrics[root.lyricIndex] ?? "" : `♪ ${root.player?.trackTitle ?? ""}${root.player?.trackArtist ? " · " + root.player.trackArtist : ""}`
                    color: "white"
                    opacity: Lyrics.hasLyrics ? 1 : .75
                    font.pixelSize: Lyrics.hasLyrics ? 30 : 20; font.weight: Font.Bold
                    style: Text.Outline; styleColor: "#99000000"
                    elide: Text.ElideRight
                }
            }
        }
    }

    component ShowButton: IslandButton {
        property bool big
        implicitWidth: big ? 72 : 48; implicitHeight: big ? 72 : 48
        leftPadding: 0; rightPadding: 0
        contentItem: MaterialIcon {
            text: parent.iconName; color: "white"; fill: 1
            fontStyle: Tokens.font.icon.size(parent.big ? 52 : 30).build()
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
    }
}
