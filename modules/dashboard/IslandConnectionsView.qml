pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus as Nexus

ColumnLayout {
    id: root
    signal closeRequested
    property string section: "wifi"
    property string errorText
    property bool loading: true
    property bool connecting
    property var passwordNetwork: null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var pairedDevices: adapter?.devices.values.filter(d => d.paired || d.connected) ?? []
    readonly property var wifiNetworks: {
        const seen = new Set();
        return Nmcli.networks.filter(n => {
            if (!n.ssid || seen.has(n.ssid)) return false;
            seen.add(n.ssid); return true;
        }).sort((a, b) => Number(b.active) - Number(a.active) || b.strength - a.strength);
    }
    readonly property int connectionCount: section === "wifi" ? Nmcli.wifiEnabled ? wifiNetworks.length : 0 : adapter?.enabled ? pairedDevices.length : 0
    implicitHeight: Math.max(140, Math.min(364, 82 + connectionCount * 52)) + (passwordNetwork ? 48 : 0) + (errorText ? 30 : 0)
    spacing: 10
    function refresh(): void {
        errorText = "";
        if (section !== "wifi") { loading = false; return; }
        loading = Nmcli.networks.length === 0;
        loadTimeout.restart();
        Nmcli.getWirelessInterfaces(() => {});
        Nmcli.getNetworks(() => { if (root) { root.loading = false; root.errorText = ""; loadTimeout.stop(); } });
    }
    Component.onCompleted: refresh()
    onSectionChanged: refresh()
    Timer {
        id: loadTimeout
        interval: 8000
        onTriggered: {
            if (root.loading) root.errorText = qsTr("Network list took too long. Try Scan again.");
            root.loading = false;
        }
    }
    function openSettings(bluetooth: bool): void {
        const label = bluetooth ? qsTr("Connected devices") : qsTr("Network");
        const index = Nexus.PageRegistry.pages.findIndex(p => p.label === label);
        Nexus.WindowFactory.create(null, {initialPage: Math.max(0, index)});
        closeRequested();
    }
    function acceptResult(result: var): void {
        connecting = false;
        errorText = result.success ? "" : result.error || qsTr("Could not connect. Check your settings.");
    }
    function connectWifi(network: var): void {
        if (connecting || network.active) return;
        errorText = ""; connecting = true;
        Nmcli.connectToNetworkWithPasswordCheck(network.ssid, network.isSecure, result => {
            if (!root) return;
            if (result.needsPassword) { root.connecting = false; root.passwordNetwork = network; password.forceActiveFocus(); }
            else root.acceptResult(result);
        }, network.bssid);
    }
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            IslandText { text: root.section === "wifi" ? "Wi-Fi" : "Bluetooth"; font.pixelSize: 14; font.weight: Font.DemiBold }
            IslandText { text: root.section === "wifi" ? Nmcli.wifiEnabled ? qsTr("Nearby networks") : qsTr("Wi-Fi is off") : root.adapter?.enabled ? qsTr("Your devices") : qsTr("Bluetooth is off"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
        }
        Item { Layout.fillWidth: true }
        IslandButton { implicitWidth: 28; implicitHeight: 28; leftPadding: 4; rightPadding: 4; iconName: root.section === "wifi" ? "refresh" : "add"; Accessible.name: root.section === "wifi" ? qsTr("Scan networks") : qsTr("Pair device"); onClicked: { if (root.section === "wifi") { Nmcli.rescanWifi(); root.refresh(); } else root.openSettings(true); } }
        IslandButton { implicitWidth: 28; implicitHeight: 28; leftPadding: 4; rightPadding: 4; iconName: "close"; Accessible.name: qsTr("Close details"); onClicked: root.closeRequested() }
    }
    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Math.min(100, Math.max(52, root.connectionCount * 52))
        clip: true
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: list
            width: parent.width
            spacing: 3
            Repeater {
                model: root.section === "wifi" && Nmcli.wifiEnabled ? root.wifiNetworks : root.section === "bluetooth" && root.adapter?.enabled ? root.pairedDevices : []
                IslandButton {
                    id: connection
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 49
                    leftPadding: 9; rightPadding: 9
                    checked: root.section === "wifi" ? modelData.active : modelData.connected
                    enabled: !root.connecting
                    Accessible.name: root.section === "wifi" ? `${modelData.ssid}, ${modelData.strength}%` : modelData.name
                    onClicked: root.section === "wifi" ? root.connectWifi(modelData) : modelData.connected ? modelData.disconnect() : modelData.connect()
                    background: Rectangle {
                        radius: 12
                        color: connection.checked ? "#2a3038" : connection.hovered ? "#25292f" : "transparent"
                        border.width: 1
                        border.color: connection.activeFocus ? "#8daeff" : connection.checked ? "#18b9d8ff" : "transparent"
                    }
                    contentItem: RowLayout {
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 10
                            color: connection.checked ? "#35465b" : "#24ffffff"
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: root.section === "wifi" ? connection.modelData.strength > 75 ? "network_wifi" : connection.modelData.strength > 50 ? "network_wifi_3_bar" : connection.modelData.strength > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar" : (connection.modelData.icon ?? "").includes("audio") ? "headphones" : "bluetooth"
                                fontStyle: Tokens.font.icon.small
                                color: connection.checked ? "#b7d8ff" : "#c5c9d0"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            IslandText { Layout.fillWidth: true; text: root.section === "wifi" ? connection.modelData.ssid : connection.modelData.name; elide: Text.ElideRight; font.pixelSize: 12; color: IslandTheme.palette.m3onSurface }
                            IslandText { Layout.fillWidth: true; text: connection.checked ? qsTr("Connected") : root.section === "wifi" ? connection.modelData.isSecure ? qsTr("Secured network") : qsTr("Open network") : qsTr("Paired"); elide: Text.ElideRight; font.pixelSize: 10; color: connection.checked ? "#a7c9ef" : "#9097a2" }
                        }
                        MaterialIcon { visible: connection.checked || root.section === "wifi" && connection.modelData.isSecure; text: connection.checked ? "check" : "lock"; fontStyle: Tokens.font.icon.small; color: connection.checked ? "#a7c9ef" : "#9097a2" }
                    }
                }
            }
            IslandText {
                Layout.fillWidth: true
                visible: root.section === "wifi" ? !Nmcli.wifiEnabled || !root.wifiNetworks.length : !root.adapter?.enabled || !root.pairedDevices.length
                text: root.section === "wifi" ? Nmcli.wifiEnabled ? root.loading ? qsTr("Looking for networks…") : qsTr("No networks yet. Scan to look nearby.") : qsTr("Turn on Wi-Fi to see nearby networks.") : root.adapter?.enabled ? qsTr("No paired devices. Add one with Pair device.") : qsTr("Turn on Bluetooth to connect your devices.")
                wrapMode: Text.WordWrap
                color: IslandTheme.palette.m3onSurfaceVariant
            }
        }
        ScrollBar.vertical: ScrollBar {}
    }
    IslandButton {
        Layout.fillWidth: true
        implicitHeight: 28
        text: root.section === "wifi" ? qsTr("Network settings…") : qsTr("Bluetooth settings…")
        onClicked: root.openSettings(root.section === "bluetooth")
        contentItem: IslandText { text: parent.text; font.pixelSize: 11; color: "#a9b3c2" }
    }
    RowLayout {
        visible: !!root.passwordNetwork
        Layout.fillWidth: true
        TextField { id: password; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: qsTr("Network password"); font.family: IslandTheme.fontFamily; Accessible.name: qsTr("Wi-Fi password"); onAccepted: if (connectPassword.enabled) connectPassword.clicked() }
        IslandButton {
            id: connectPassword
            text: qsTr("Connect"); accent: true; enabled: !!password.text && !root.connecting
            onClicked: {
                if (root.connecting || !root.passwordNetwork || !password.text) return;
                root.connecting = true;
                Nmcli.connectToNetwork(root.passwordNetwork.ssid, password.text, root.passwordNetwork.bssid, result => { if (!root) return; root.acceptResult(result); if (result.success) root.passwordNetwork = null; });
                password.clear();
            }
        }
        IslandButton { iconName: "close"; Accessible.name: qsTr("Cancel password entry"); onClicked: { root.passwordNetwork = null; password.clear(); } }
    }
    IslandText { visible: !!root.errorText; Layout.fillWidth: true; text: root.errorText; maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.WordWrap; color: IslandTheme.palette.m3error }
}
