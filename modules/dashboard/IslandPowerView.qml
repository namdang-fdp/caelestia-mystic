pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services
import qs.utils

FocusScope {
    id: root
    property int pendingAction: -1
    property bool executing: false
    readonly property var actions: [
        { label: qsTr("Logout"), iconName: Config.session.icons.logout, command: Config.session.commands.logout },
        { label: qsTr("Shutdown"), iconName: Config.session.icons.shutdown, command: Config.session.commands.shutdown },
        { label: qsTr("Hibernate"), iconName: Config.session.icons.hibernate, command: Config.session.commands.hibernate },
        { label: qsTr("Restart"), iconName: Config.session.icons.reboot, command: Config.session.commands.reboot }
    ]
    signal closeRequested
    implicitHeight: 276
    onVisibleChanged: if (!visible) pendingAction = -1

    function confirm(): void {
        if (executing || pendingAction < 0 || pendingAction >= actions.length) return;
        const command = actions[pendingAction].command;
        if (!command || command.length === 0) return;
        executing = true;
        if (!SessionManager.exec(command)) Quickshell.execDetached(command);
        closeRequested();
    }

    Keys.onEscapePressed: event => {
        if (pendingAction >= 0) pendingAction = -1;
        else closeRequested();
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            spacing: 16
            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                radius: 20
                color: Qt.alpha(IslandTheme.palette.m3secondary, 0.08)
                AnimatedImage {
                    id: mascot
                    anchors.fill: parent
                    anchors.margins: 4
                    source: Paths.absolutePath(Config.paths.sessionGif)
                    asynchronous: true
                    fillMode: AnimatedImage.PreserveAspectFit
                    playing: visible && Config.general.sessionGifSpeed > 0
                    speed: Math.max(0.01, Config.general.sessionGifSpeed)
                    sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !Config.paths.sessionGif || mascot.status === AnimatedImage.Error
                    text: "power_settings_new"
                    color: IslandTheme.palette.m3secondary
                    fontStyle: Tokens.font.icon.large
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                IslandText { text: qsTr("Session & power"); islandFont: Tokens.font.title.medium }
                IslandText {
                    Layout.fillWidth: true
                    text: qsTr("Choose an action, then confirm.")
                    color: IslandTheme.palette.m3onSurfaceVariant
                    islandFont: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            Repeater {
                model: root.actions
                IslandButton {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 44
                    iconName: modelData.iconName
                    text: modelData.label
                    checked: root.pendingAction === index
                    enabled: !root.executing && modelData.command.length > 0
                    onClicked: { root.pendingAction = index; cancel.forceActiveFocus(); }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            IslandText {
                Layout.fillWidth: true
                text: root.pendingAction >= 0 ? qsTr("%1 this session?").arg(root.actions[root.pendingAction].label) : qsTr("GIF and playback speed can be changed in Settings.")
                color: root.pendingAction >= 0 ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3onSurfaceVariant
                islandFont: Tokens.font.label.medium
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.pendingAction >= 0
                Item { Layout.fillWidth: true }
                IslandButton { id: cancel; text: qsTr("Cancel"); enabled: !root.executing; onClicked: root.pendingAction = -1 }
                IslandButton { text: qsTr("Confirm"); accent: true; enabled: !root.executing; onClicked: root.confirm() }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
