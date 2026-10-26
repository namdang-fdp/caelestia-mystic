pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root
    required property ShellScreen screen
    property string displayName: ""
    readonly property var monitor: Brightness.getMonitor(displayName) ?? Brightness.monitors.find(m => m.isInternal) ?? Brightness.getMonitorForScreen(screen)
    function nextDisplay(): void {
        const available = Brightness.monitors.filter(m => m.supported);
        const index = available.indexOf(monitor);
        if (available.length) displayName = available[(index + 1) % available.length].modelData.name;
    }
    function displayLabel(): string {
        return monitor?.isInternal ? qsTr("Built-in") : monitor?.modelData.model || monitor?.modelData.name || qsTr("Display");
    }
    onMonitorChanged: monitor?.initBrightness()
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool dragging: displaySlider.pressed || soundSlider.pressed
    signal pageRequested(string page)
    signal detailRequested(string section)
    signal closeRequested
    implicitHeight: 234 + (monitor?.lastError ? 30 : 0)
    spacing: 16
    Component.onCompleted: { Nmcli.getWirelessInterfaces(() => {}); monitor?.initBrightness(); }
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 22
        IslandButton {
            implicitHeight: 24; leftPadding: 0; rightPadding: 0
            Accessible.name: qsTr("Open calendar and system information")
            onClicked: root.pageRequested("info")
            contentItem: Row {
                spacing: 7
                IslandText { id: clock; text: Time.timeStr; font.pixelSize: 13; font.weight: Font.DemiBold }
                IslandText { text: Time.format("ddd, MMM d"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant; anchors.baseline: clock.baseline }
            }
        }
        Item { Layout.fillWidth: true }
        IslandButton {
            implicitHeight: 24; leftPadding: 0; rightPadding: 0
            Accessible.name: qsTr("Battery and power information")
            onClicked: root.pageRequested("info")
            contentItem: IslandBattery { color: "transparent"; implicitHeight: 22 }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        ConnectionCard {
            title: "Wi-Fi"; iconName: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
            detail: !Nmcli.wifiEnabled ? qsTr("Off") : Nmcli.active?.ssid || Nmcli.wirelessInterfaces.find(i => Nmcli.isConnectedState(i.state))?.connection || qsTr("Not connected")
            checked: Nmcli.wifiEnabled
            onClicked: root.detailRequested("wifi")
            onToggleRequested: Nmcli.toggleWifi(() => {})
        }
        ConnectionCard {
            title: "Bluetooth"; iconName: "bluetooth"
            detail: !root.adapter ? qsTr("No adapter") : !root.adapter.enabled ? qsTr("Off") : root.adapter.devices.values.find(d => d.connected)?.name || qsTr("On")
            checked: root.adapter?.enabled ?? false
            toggleEnabled: !!root.adapter
            onClicked: root.detailRequested("bluetooth")
            onToggleRequested: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IslandText { text: qsTr("Display"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
            IslandButton {
                implicitHeight: 18; leftPadding: 4; rightPadding: 4
                Accessible.name: qsTr("Change display, currently %1").arg(root.displayLabel())
                onClicked: root.nextDisplay()
                contentItem: IslandText { text: root.displayLabel() + " ›"; font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
            }
            Item { Layout.fillWidth: true }
            IslandText { text: root.monitor?.supported ? `${Math.round((root.monitor?.brightness ?? 0) * 100)}%` : "—"; font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
        }
        IslandSlider {
            id: displaySlider
            Layout.fillWidth: true
            label: qsTr("Brightness"); iconName: "brightness_6"
            value: root.monitor?.brightness ?? 0
            enabled: root.monitor?.supported ?? false
            onMoved: root.monitor?.setBrightness(value)
        }
        IslandText { Layout.fillWidth: true; visible: !!root.monitor?.lastError; text: root.monitor?.lastError ?? ""; font.pixelSize: 10; color: IslandTheme.palette.m3error; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            IslandText { text: qsTr("Sound"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
            IslandText { Layout.fillWidth: true; text: Audio.sink?.description ?? ""; font.pixelSize: 11; color: IslandTheme.palette.m3outline; elide: Text.ElideRight }
            IslandText { text: Audio.muted ? qsTr("Muted") : `${Math.round(Audio.volume * 100)}%`; font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
        }
        IslandSlider {
            id: soundSlider
            Layout.fillWidth: true
            label: qsTr("Volume"); iconName: Audio.muted ? "volume_off" : "volume_up"
            value: Audio.volume; to: 1
            enabled: !!Audio.sink?.audio
            onMoved: Audio.setVolume(value)
        }
    }
    // iOS-style tile: the round button toggles, the rest of the tile opens details.
    component ConnectionCard: IslandButton {
        id: card
        required property string title
        required property string detail
        property bool toggleEnabled: true
        signal toggleRequested
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 60
        leftPadding: 10; rightPadding: 12; topPadding: 10; bottomPadding: 10
        Accessible.name: qsTr("%1 details, %2").arg(title).arg(detail)
        background: Rectangle {
            radius: 18
            color: card.down ? IslandTheme.palette.cardHover : card.hovered ? IslandTheme.palette.cardHover : IslandTheme.palette.card
            border.width: card.activeFocus ? 2 : 0
            border.color: IslandTheme.palette.focus
            Behavior on color { ColorAnimation { duration: 140 * Tokens.anim.durations.scale } }
        }
        contentItem: RowLayout {
            spacing: 10
            IslandButton {
                implicitWidth: 40; implicitHeight: 40
                leftPadding: 0; rightPadding: 0
                enabled: card.toggleEnabled
                Accessible.name: qsTr("%1 %2").arg(card.checked ? qsTr("Turn off") : qsTr("Turn on")).arg(card.title)
                onClicked: card.toggleRequested()
                background: Rectangle {
                    radius: width / 2
                    color: card.checked ? IslandTheme.palette.accent : IslandTheme.palette.chip
                    scale: parent.down ? .92 : 1
                    Behavior on color { ColorAnimation { duration: 180 * Tokens.anim.durations.scale } }
                    Behavior on scale { NumberAnimation { duration: 120 * Tokens.anim.durations.scale } }
                }
                contentItem: Item {
                    MaterialIcon { anchors.centerIn: parent; text: card.iconName; fill: card.checked ? 1 : 0; color: IslandTheme.palette.m3onSurface; fontStyle: Tokens.font.icon.small }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                IslandText { Layout.fillWidth: true; text: card.title; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                IslandText { Layout.fillWidth: true; text: card.detail; font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight }
            }
        }
    }
}
