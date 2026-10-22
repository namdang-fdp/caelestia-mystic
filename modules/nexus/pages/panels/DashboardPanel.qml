pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root
    title: qsTr("Dynamic Island")
    isSubPage: true
    property real lastGifSpeed: Math.max(1, Config.general.sessionGifSpeed)
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2
        SectionHeader { first: true; text: qsTr("Island") }
        ToggleRow {
            first: true
            text: qsTr("Enabled")
            subtext: qsTr("Clock and battery at rest. Super+I opens workspaces, controls and notifications.")
            checked: Config.dashboard.enabled
            onToggled: GlobalConfig.dashboard.enabled = checked
        }
        ToggleRow {
            text: qsTr("Preview on hover")
            subtext: qsTr("Show workspace thumbnails on hover without taking keyboard focus.")
            checked: Config.dashboard.showOnHover
            onToggled: GlobalConfig.dashboard.showOnHover = checked
        }
        ToggleRow {
            last: true
            text: qsTr("Music view")
            subtext: qsTr("Compact playback, controls and lyrics. Right-click the capsule or use Super+V for clipboard history.")
            checked: Config.dashboard.showMedia
            onToggled: GlobalConfig.dashboard.showMedia = checked
        }

        SectionHeader { text: qsTr("Appearance") }
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: gifRow.implicitHeight + Tokens.padding.large * 2
            RowLayout {
                id: gifRow
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.large
                Rectangle {
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 88
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerHigh
                    AnimatedImage {
                        id: preview
                        anchors.fill: parent
                        anchors.margins: 4
                        source: Paths.absolutePath(Config.paths.sessionGif)
                        fillMode: AnimatedImage.PreserveAspectFit
                        asynchronous: true
                        speed: Math.max(0.01, Config.general.sessionGifSpeed)
                        playing: visible && Config.general.sessionGifSpeed > 0
                        sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !Config.paths.sessionGif || preview.status === AnimatedImage.Error
                        text: "hide_image"
                        fontStyle: Tokens.font.icon.large
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    StyledText { text: qsTr("Power menu GIF"); font: Tokens.font.body.medium }
                    StyledText {
                        Layout.fillWidth: true
                        text: preview.status === AnimatedImage.Error ? qsTr("Could not load this GIF") : Paths.shortenHome(Config.paths.sessionGif)
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideMiddle
                    }
                    IconTextButton {
                        text: qsTr("Choose GIF")
                        icon: "folder_open"
                        type: IconTextButton.Tonal
                        isRound: true
                        onClicked: gifDialog.open()
                        FileDialog {
                            id: gifDialog
                            title: qsTr("Choose a power menu GIF")
                            filterLabel: qsTr("GIF images")
                            filters: ["gif"]
                            onAccepted: path => GlobalConfig.paths.sessionGif = path
                        }
                    }
                }
            }
        }
        ToggleRow {
            Layout.topMargin: Tokens.spacing.small
            first: true
            text: qsTr("Animate GIF")
            subtext: qsTr("Playback runs only while the power menu or this preview is visible.")
            checked: Config.general.sessionGifSpeed > 0
            onToggled: {
                if (!checked) root.lastGifSpeed = Config.general.sessionGifSpeed;
                GlobalConfig.general.sessionGifSpeed = checked ? root.lastGifSpeed : 0;
            }
        }
        SliderRow {
            last: true
            icon: "speed"
            label: qsTr("GIF playback speed")
            valueLabel: Config.general.sessionGifSpeed === 0 ? qsTr("Paused") : `${Config.general.sessionGifSpeed.toFixed(1)}×`
            value: Config.general.sessionGifSpeed / 3
            onMoved: v => {
                const speed = Math.round(v * 30) / 10;
                if (speed > 0) root.lastGifSpeed = speed;
                GlobalConfig.general.sessionGifSpeed = speed;
            }
        }
    }

}
