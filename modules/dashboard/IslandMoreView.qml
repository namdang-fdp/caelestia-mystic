pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Last carousel page: microphone, quick toggles, links to the remaining detail
// pages and background apps. Pages that already have a carousel slot
// (Windows, Clipboard) or another entry point (Info) are not repeated here.
ColumnLayout {
    id: root
    required property ShellScreen screen
    signal pageRequested(string page)
    property bool menuOpen
    readonly property bool dragging: micSlider.pressed || nightLightSlider.pressed
    spacing: 16

    IslandText { text: qsTr("More"); font.pixelSize: 15; font.weight: Font.DemiBold }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            IslandText { text: qsTr("Microphone"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
            IslandButton {
                implicitHeight: 18; leftPadding: 4; rightPadding: 4
                enabled: !!Audio.source?.audio
                Accessible.name: Audio.sourceMuted ? qsTr("Unmute microphone") : qsTr("Mute microphone")
                onClicked: Audio.source.audio.muted = !Audio.sourceMuted
                contentItem: IslandText { text: Audio.sourceMuted ? qsTr("Unmute") : qsTr("Mute"); font.pixelSize: 11; color: Audio.sourceMuted ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurfaceVariant }
            }
            Item { Layout.fillWidth: true }
            IslandText { text: Audio.sourceMuted ? qsTr("Muted") : `${Math.round(Audio.sourceVolume * 100)}%`; font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
        }
        IslandSlider {
            id: micSlider
            Layout.fillWidth: true
            label: qsTr("Microphone volume"); iconName: Audio.sourceMuted ? "mic_off" : "mic"
            value: Audio.sourceVolume; to: GlobalConfig.services.maxVolume
            enabled: !!Audio.source?.audio
            onMoved: Audio.setSourceVolume(value)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        ToggleTile { title: qsTr("Keep Awake"); iconName: "coffee"; checked: IdleInhibitor.enabled; onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled }
        ToggleTile { visible: NightLight.available; title: qsTr("Night Light"); iconName: "nightlight"; checked: NightLight.enabled; onClicked: NightLight.toggle() }
        ToggleTile { visible: VPN.enabled; title: VPN.connecting ? qsTr("Connecting") : qsTr("VPN"); iconName: "vpn_key"; checked: VPN.connected; enabled: !VPN.connecting; onClicked: VPN.toggle() }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: -6
        visible: NightLight.available && NightLight.enabled
        spacing: 10
        IslandSlider {
            id: nightLightSlider
            visible: !NightLight.error
            Layout.fillWidth: true
            iconName: "nightlight"
            label: qsTr("Night light temperature")
            // Left is warmer: the slider runs from the maximum down to the minimum kelvin.
            from: NightLight.maximumTemperature
            to: NightLight.minimumTemperature
            stepSize: 100
            value: NightLight.temperature
            onMoved: NightLight.setTemperature(value)
        }
        IslandText {
            Layout.fillWidth: !!NightLight.error
            Layout.preferredWidth: 52
            horizontalAlignment: NightLight.error ? Text.AlignLeft : Text.AlignRight
            text: NightLight.error ? qsTr("Night light: %1").arg(NightLight.error) : `${NightLight.temperature} K`
            color: NightLight.error ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurfaceVariant
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    // Grouped list, iOS settings style.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: links.implicitHeight
        radius: 16
        color: IslandTheme.palette.card
        ColumnLayout {
            id: links
            anchors.left: parent.left; anchors.right: parent.right
            spacing: 0
            LinkRow { title: qsTr("Notifications"); detail: Notifs.notClosed.length ? Notifs.notClosed.length.toString() : ""; page: "notifications" }
            Rectangle { Layout.fillWidth: true; Layout.leftMargin: 14; implicitHeight: 1; color: IslandTheme.palette.divider }
            LinkRow { title: qsTr("Weather"); detail: Weather.cc ? Weather.temp : ""; page: "weather" }
            Rectangle { Layout.fillWidth: true; Layout.leftMargin: 14; implicitHeight: 1; color: IslandTheme.palette.divider }
            LinkRow { title: qsTr("Power"); page: "power" }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: IslandTray.items.length > 0
        spacing: 8
        IslandText { text: qsTr("Background apps"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: IslandTray.items
                IslandButton {
                    id: trayButton
                    required property var modelData
                    implicitWidth: 36
                    implicitHeight: 36
                    Accessible.name: modelData.tooltipTitle || modelData.title || modelData.id
                    contentItem: IconImage { source: Icons.getTrayIcon(trayButton.modelData.id, trayButton.modelData.icon); implicitSize: 20 }
                    function showMenu(): void {
                        if (!modelData.hasMenu) return;
                        root.menuOpen = true;
                        nativeMenu.open();
                    }
                    onClicked: modelData.onlyMenu ? showMenu() : modelData.activate()
                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: trayButton.showMenu() }
                    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: trayButton.modelData.secondaryActivate() }
                    QsMenuAnchor {
                        id: nativeMenu
                        anchor.item: trayButton
                        anchor.edges: Edges.Bottom
                        anchor.gravity: Edges.Bottom
                        menu: trayButton.modelData.menu
                        onClosed: root.menuOpen = false
                    }
                }
            }
        }
    }

    // Round toggle with its label underneath, like Control Center.
    component ToggleTile: IslandButton {
        id: tile
        required property string title
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 72
        Accessible.name: qsTr("%1, %2").arg(title).arg(checked ? qsTr("on") : qsTr("off"))
        background: Rectangle {
            radius: 18
            color: tile.hovered || tile.down ? IslandTheme.palette.cardHover : IslandTheme.palette.card
            border.width: tile.activeFocus ? 2 : 0
            border.color: IslandTheme.palette.focus
            Behavior on color { ColorAnimation { duration: 140 * Tokens.anim.durations.scale } }
        }
        contentItem: ColumnLayout {
            spacing: 6
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 34; implicitHeight: 34; radius: 17
                color: tile.checked ? IslandTheme.palette.accent : IslandTheme.palette.chip
                scale: tile.down ? .92 : 1
                Behavior on color { ColorAnimation { duration: 180 * Tokens.anim.durations.scale } }
                Behavior on scale { NumberAnimation { duration: 120 * Tokens.anim.durations.scale } }
                MaterialIcon { anchors.centerIn: parent; text: tile.iconName; fill: tile.checked ? 1 : 0; color: IslandTheme.palette.m3onSurface; fontStyle: Tokens.font.icon.small }
            }
            IslandText { Layout.alignment: Qt.AlignHCenter; text: tile.title; font.pixelSize: 11; color: tile.checked ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3onSurfaceVariant }
        }
    }
    component LinkRow: IslandButton {
        id: link
        required property string title
        required property string page
        property string detail
        Layout.fillWidth: true
        implicitHeight: 44
        leftPadding: 14; rightPadding: 12
        Accessible.name: title
        onClicked: root.pageRequested(page)
        background: Rectangle {
            radius: 16
            color: link.hovered || link.down ? IslandTheme.palette.card : "transparent"
            Behavior on color { ColorAnimation { duration: 120 * Tokens.anim.durations.scale } }
        }
        contentItem: RowLayout {
            spacing: 8
            IslandText { Layout.fillWidth: true; text: link.title; font.pixelSize: 13 }
            IslandText { visible: !!link.detail; text: link.detail; font.pixelSize: 13; color: IslandTheme.palette.m3onSurfaceVariant }
            IslandText { text: "›"; font.pixelSize: 17; color: IslandTheme.palette.m3outline }
        }
    }
}
