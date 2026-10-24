pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.dashboard

// Island-style lock screen: clock on top, optional now-playing card, avatar and
// password pill at the bottom. Uses Geist at its native width (no synthetic
// stretching), so Vietnamese dates and titles render cleanly.
Item {
    id: root

    required property var lock
    readonly property Pam pam: lock.pam
    readonly property bool busy: pam.passwd.active || pam.howdy.active
    readonly property var player: Players.active
    readonly property bool hasMedia: !!player && player.playbackState !== MprisPlaybackState.Stopped
    readonly property real s: Math.max(.75, Math.min(1.25, height / 1080))
    property string realName

    LockMessage {
        id: message
        pam: root.pam
    }

    Process {
        running: true
        command: ["getent", "passwd", SysInfo.user]
        stdout: StdioCollector {
            onStreamFinished: root.realName = (text.split(":")[4] ?? "").split(",")[0].trim()
        }
    }

    Connections {
        target: root.pam
        function onFlashMsg(): void { shake.restart(); }
    }

    // Keyboard input always goes to PAM, wherever the pointer is.
    focus: true
    onActiveFocusChanged: if (!activeFocus) forceActiveFocus()
    Keys.onPressed: event => {
        if (!root.lock.unlocking) root.pam.handleKey(event);
    }
    TapHandler { onTapped: root.forceActiveFocus() }

    // Status corner.
    RowLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24 * root.s
        spacing: 14
        MaterialIcon { visible: Nmcli.wifiEnabled; text: Nmcli.active ? "wifi" : "wifi_off"; color: "white"; opacity: .85; fontStyle: Tokens.font.icon.small }
        Row {
            visible: UPower.displayDevice.isLaptopBattery
            spacing: 4
            MaterialIcon { anchors.verticalCenter: parent.verticalCenter; text: Icons.getBatteryIcon(UPower.displayDevice.percentage, !UPower.onBattery); color: "white"; opacity: .85; fontStyle: Tokens.font.icon.small }
            IslandText { anchors.verticalCenter: parent.verticalCenter; text: `${Math.round(UPower.displayDevice.percentage * 100)}%`; color: "white"; opacity: .85; font.pixelSize: 13; font.weight: Font.Medium }
        }
    }

    // Clock.
    ColumnLayout {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * .11
        spacing: 0
        IslandText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd, d MMMM")
            color: "white"
            opacity: .85
            font.pixelSize: Math.round(22 * root.s)
            font.weight: Font.Medium
        }
        IslandText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -6 * root.s
            text: Time.format(GlobalConfig.services.useTwelveHourClock ? "h:mm" : "HH:mm")
            color: "white"
            font.pixelSize: Math.round(128 * root.s)
            font.weight: Font.DemiBold
            font.letterSpacing: -3 * root.s
            font.features: { "tnum": 1 }
        }
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            visible: !!Weather.cc
            spacing: 6
            MaterialIcon { anchors.verticalCenter: parent.verticalCenter; text: Weather.icon; color: "white"; opacity: .8; fontStyle: Tokens.font.icon.small }
            IslandText { anchors.verticalCenter: parent.verticalCenter; text: [Weather.temp, Weather.city].filter(s => s).join("  ·  "); color: "white"; opacity: .8; font.pixelSize: Math.round(14 * root.s) }
        }
    }

    // Now playing.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clock.bottom
        anchors.topMargin: 36 * root.s
        visible: root.hasMedia
        width: 380 * root.s
        height: 88 * root.s
        radius: 26 * root.s
        color: Qt.alpha("black", .32)
        border.width: 1
        border.color: Qt.alpha("white", .08)
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12 * root.s
            spacing: 12 * root.s
            ClippingRectangle {
                Layout.preferredWidth: parent.height; Layout.preferredHeight: parent.height
                radius: 14 * root.s
                color: Qt.alpha("white", .1)
                Image { anchors.fill: parent; source: Players.getArtUrl(root.player); sourceSize: Qt.size(160, 160); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                MaterialIcon { anchors.centerIn: parent; visible: !Players.getArtUrl(root.player); text: "music_note"; color: "white"; fontStyle: Tokens.font.icon.medium }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                IslandText { Layout.fillWidth: true; text: root.player?.trackTitle || qsTr("Unknown track"); color: "white"; font.pixelSize: Math.round(15 * root.s); font.weight: Font.DemiBold; elide: Text.ElideRight }
                IslandText { Layout.fillWidth: true; text: root.player?.trackArtist || Players.getIdentity(root.player); color: "white"; opacity: .7; font.pixelSize: Math.round(13 * root.s); elide: Text.ElideRight }
            }
            MediaButton { iconName: "skip_previous"; enabled: !!root.player?.canGoPrevious; onClicked: root.player.previous() }
            MediaButton { iconName: root.player?.isPlaying ? "pause" : "play_arrow"; enabled: !!root.player?.canTogglePlaying; onClicked: root.player.togglePlaying() }
            MediaButton { iconName: "skip_next"; enabled: !!root.player?.canGoNext; onClicked: root.player.next() }
        }
    }

    // Identity and password.
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * .1
        spacing: 12 * root.s

        ClippingRectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 76 * root.s; implicitHeight: implicitWidth
            radius: width / 2
            color: Qt.alpha("white", .15)
            border.width: 2
            border.color: Qt.alpha("white", .25)
            Image {
                id: avatar
                anchors.fill: parent
                source: `file://${Paths.home}/.face`
                sourceSize: Qt.size(160, 160)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            MaterialIcon { anchors.centerIn: parent; visible: avatar.status !== Image.Ready; text: "person"; color: "white"; fontStyle: Tokens.font.icon.large }
        }
        IslandText {
            Layout.alignment: Qt.AlignHCenter
            text: root.realName || SysInfo.user
            color: "white"
            font.pixelSize: Math.round(17 * root.s)
            font.weight: Font.DemiBold
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 260 * root.s
            implicitHeight: 40 * root.s
            Rectangle {
                id: pill
                width: parent.width; height: parent.height
                radius: height / 2
                color: Qt.alpha("white", root.pam.buffer ? .22 : .16)
                border.width: 1
                border.color: message.error ? Qt.alpha(IslandTheme.palette.m3error, .7) : Qt.alpha("white", .12)
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                IslandText {
                    anchors.centerIn: parent
                    visible: !root.pam.buffer && !root.busy
                    text: root.pam.state === Pam.MaxTries ? qsTr("Locked out") : qsTr("Enter Password")
                    color: "white"
                    opacity: .6
                    font.pixelSize: Math.round(13 * root.s)
                }
                Row {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -12 * root.s
                    spacing: 6 * root.s
                    visible: !!root.pam.buffer && !root.busy
                    Repeater {
                        model: Math.min(root.pam.buffer.length, 20)
                        Rectangle {
                            width: 8 * root.s; height: width; radius: width / 2
                            color: "white"
                            NumberAnimation on scale { from: 0; to: 1; duration: 140; easing.type: Easing.OutBack }
                        }
                    }
                }
                IslandSpinner { anchors.centerIn: parent; running: root.busy; color: "white" }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 5 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height - 10 * root.s; height: width; radius: width / 2
                    color: Qt.alpha("white", .9)
                    opacity: root.pam.buffer && !root.busy ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    MaterialIcon { anchors.centerIn: parent; text: "arrow_forward"; color: "black"; fontStyle: Tokens.font.icon.small }
                    TapHandler { enabled: parent.opacity > 0; onTapped: root.pam.passwd.start() }
                }
                SequentialAnimation {
                    id: shake
                    loops: 1
                    NumberAnimation { target: pill; property: "x"; to: 12; duration: 50 }
                    NumberAnimation { target: pill; property: "x"; to: -10; duration: 60 }
                    NumberAnimation { target: pill; property: "x"; to: 6; duration: 60 }
                    NumberAnimation { target: pill; property: "x"; to: 0; duration: 60 }
                }
            }
        }

        IslandText {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 420 * root.s
            Layout.preferredHeight: Math.round(36 * root.s)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.Wrap
            maximumLineCount: 2
            text: message.msg || message.hint
            color: message.error ? "#ffb4ab" : "white"
            opacity: message.error ? 1 : .65
            font.pixelSize: Math.round(12 * root.s)
        }
    }

    // Notification count only: contents stay private on the lock screen.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24 * root.s
        visible: Notifs.notClosed.length > 0
        implicitWidth: notifRow.implicitWidth + 24
        implicitHeight: 30
        radius: 15
        color: Qt.alpha("black", .3)
        Row {
            id: notifRow
            anchors.centerIn: parent
            spacing: 6
            MaterialIcon { anchors.verticalCenter: parent.verticalCenter; text: "notifications"; color: "white"; opacity: .8; fontStyle: Tokens.font.icon.small }
            IslandText {
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.notClosed.length === 1 ? qsTr("1 notification") : qsTr("%1 notifications").arg(Notifs.notClosed.length)
                color: "white"; opacity: .8
                font.pixelSize: 12
            }
        }
    }

    component MediaButton: Item {
        id: button
        property string iconName
        signal clicked
        Layout.preferredWidth: 34 * root.s
        Layout.preferredHeight: 34 * root.s
        opacity: enabled ? 1 : .35
        Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.alpha("white", hover.hovered ? .16 : 0) }
        MaterialIcon { anchors.centerIn: parent; text: button.iconName; color: "white"; fill: 1; fontStyle: Tokens.font.icon.medium }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: button.clicked() }
    }
}
