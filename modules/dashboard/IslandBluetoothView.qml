pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus as Nexus
import "helpers/ActivityLogic.js" as Logic

// Bluetooth drill-in page: paired devices with battery, nearby devices found
// while the page is open.
ColumnLayout {
    id: root
    signal backRequested
    signal closeRequested
    property string confirmForget
    property var pendingPair: null
    property bool startedDiscovery
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabledAdapter: adapter?.enabled ?? false
    readonly property var devices: adapter?.devices.values ?? []
    readonly property var myDevices: devices.filter(d => d.paired || d.bonded || d.connected).sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name))
    // Unnamed devices only advertise their address; they are noise in a picker.
    readonly property var nearby: devices.filter(d => !d.paired && !d.bonded && !d.connected && d.deviceName && d.deviceName.replace(/[-:]/g, "") !== d.address.replace(/:/g, ""))
    spacing: 10

    function deviceIcon(icon: string): string { return Logic.bluetoothIcon(icon); }
    function status(device: var): string {
        if (device.state === BluetoothDeviceState.Connecting) return qsTr("Connecting…");
        if (device.state === BluetoothDeviceState.Disconnecting) return qsTr("Disconnecting…");
        if (device.pairing) return qsTr("Pairing…");
        if (device.connected) return qsTr("Connected");
        return device.paired || device.bonded ? qsTr("Not connected") : qsTr("Tap to pair");
    }
    function busy(device: var): bool {
        return device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting;
    }
    function toggle(device: var): void {
        confirmForget = "";
        if (busy(device)) return;
        if (device.connected) device.disconnect();
        else device.connect();
    }
    function pair(device: var): void {
        if (busy(device)) return;
        pendingPair = device;
        device.trusted = true;
        device.pair();
    }
    function forget(device: var): void {
        if (confirmForget !== device.address) { confirmForget = device.address; return; }
        confirmForget = "";
        device.forget();
    }
    function setDiscovery(on: bool): void {
        if (!adapter) return;
        if (on && adapter.enabled && !adapter.discovering) { adapter.discovering = true; startedDiscovery = true; }
        else if (!on && startedDiscovery) { adapter.discovering = false; startedDiscovery = false; }
    }
    function openSettings(): void {
        const index = Nexus.PageRegistry.pages.findIndex(p => p.label === qsTr("Connected devices"));
        Nexus.WindowFactory.create(null, {initialPage: Math.max(0, index)});
        closeRequested();
    }
    onEnabledAdapterChanged: setDiscovery(enabledAdapter)
    Component.onCompleted: setDiscovery(true)
    Component.onDestruction: setDiscovery(false)
    Connections {
        target: root.pendingPair
        function onPairedChanged(): void {
            const device = root.pendingPair;
            if (!device?.paired) return;
            root.pendingPair = null;
            device.connect();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        IslandButton { iconName: "chevron_left"; implicitWidth: 30; implicitHeight: 30; leftPadding: 5; rightPadding: 5; Accessible.name: qsTr("Back to Control Center"); onClicked: root.backRequested() }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            IslandText { text: "Bluetooth"; font.pixelSize: 16; font.weight: Font.DemiBold }
            IslandText { text: !root.adapter ? qsTr("No adapter found") : !root.enabledAdapter ? qsTr("Off") : root.adapter.name || qsTr("On"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        IslandSwitch { checked: root.enabledAdapter; enabled: !!root.adapter; Accessible.name: "Bluetooth"; onClicked: root.adapter.enabled = !root.adapter.enabled }
    }

    Flickable {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 320)
        visible: root.enabledAdapter
        clip: true
        contentHeight: sections.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
        ColumnLayout {
            id: sections
            width: list.width
            spacing: 2
            SectionLabel { visible: root.myDevices.length; text: qsTr("My devices") }
            Repeater {
                model: root.myDevices
                IslandListRow {
                    id: deviceRow
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.name || modelData.deviceName
                    subtitle: root.confirmForget === modelData.address ? qsTr("Tap the bin again to forget this device") : root.status(modelData)
                    danger: root.confirmForget === modelData.address
                    iconName: root.deviceIcon(modelData.icon)
                    active: modelData.connected
                    busy: root.busy(modelData)
                    onClicked: root.toggle(modelData)
                    Row {
                        spacing: 2
                        visible: deviceRow.modelData.connected && deviceRow.modelData.batteryAvailable
                        MaterialIcon { anchors.verticalCenter: parent.verticalCenter; text: Icons.getBatteryIcon(deviceRow.modelData.battery); color: deviceRow.modelData.battery <= .2 ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurfaceVariant; fontStyle: Tokens.font.icon.small }
                        IslandText { anchors.verticalCenter: parent.verticalCenter; text: `${Math.round(deviceRow.modelData.battery * 100)}%`; font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
                    }
                    IslandButton {
                        visible: deviceRow.hovered || root.confirmForget === deviceRow.modelData.address
                        implicitWidth: 28; implicitHeight: 28; leftPadding: 4; rightPadding: 4
                        iconName: "delete"
                        checked: root.confirmForget === deviceRow.modelData.address
                        Accessible.name: qsTr("Forget %1").arg(deviceRow.text)
                        onClicked: root.forget(deviceRow.modelData)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6; Layout.rightMargin: 8
                SectionLabel { Layout.topMargin: 0; text: qsTr("Nearby devices") }
                IslandSpinner { running: root.adapter?.discovering ?? false }
            }
            Repeater {
                model: root.nearby
                IslandListRow {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.name || modelData.deviceName
                    subtitle: root.status(modelData)
                    iconName: root.deviceIcon(modelData.icon)
                    busy: root.busy(modelData)
                    onClicked: root.pair(modelData)
                    MaterialIcon { text: "add"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.small }
                }
            }
            IslandText {
                Layout.fillWidth: true; Layout.leftMargin: 8; Layout.bottomMargin: 8
                visible: !root.nearby.length
                text: root.adapter?.discovering ? qsTr("Looking for devices in pairing mode…") : qsTr("No new devices found")
                color: IslandTheme.palette.m3outline
                font.pixelSize: 11
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 16; Layout.bottomMargin: 16
        visible: !root.enabledAdapter
        spacing: 6
        MaterialIcon { Layout.alignment: Qt.AlignHCenter; text: "bluetooth_disabled"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.extraLarge }
        IslandText { Layout.alignment: Qt.AlignHCenter; text: root.adapter ? qsTr("Bluetooth is turned off") : qsTr("No Bluetooth adapter"); font.pixelSize: 13; font.weight: Font.Medium }
        IslandText { Layout.alignment: Qt.AlignHCenter; visible: !!root.adapter; text: qsTr("Turn it on to connect headphones and more."); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: IslandTheme.palette.cardBorder }
    IslandButton {
        Layout.fillWidth: true
        implicitHeight: 30
        onClicked: root.openSettings()
        Accessible.name: qsTr("Bluetooth settings")
        contentItem: RowLayout {
            IslandText { Layout.fillWidth: true; text: qsTr("Bluetooth settings…"); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant }
            MaterialIcon { text: "chevron_right"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.small }
        }
    }

    component SectionLabel: IslandText {
        Layout.fillWidth: true
        Layout.topMargin: 6; Layout.bottomMargin: 2; Layout.leftMargin: 8
        font.pixelSize: 11; font.weight: Font.DemiBold
        color: IslandTheme.palette.m3outline
    }
}
