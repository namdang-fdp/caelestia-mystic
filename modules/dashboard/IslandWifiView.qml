pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus as Nexus

// Wi-Fi drill-in page: connected network hero, known and nearby networks with
// inline password entry.
ColumnLayout {
    id: root
    signal backRequested
    signal closeRequested
    property bool loading: Nmcli.networks.length === 0
    property bool showDetails
    property string joiningSsid
    property string passwordSsid
    property string errorSsid
    property string errorText
    property string confirmForget
    readonly property var active: Nmcli.active
    readonly property var networks: {
        const seen = new Set();
        return Nmcli.networks.filter(n => {
            if (!n.ssid || seen.has(n.ssid)) return false;
            seen.add(n.ssid); return true;
        }).sort((a, b) => b.strength - a.strength);
    }
    readonly property var known: networks.filter(n => !n.active && Nmcli.hasSavedProfile(n.ssid))
    readonly property var others: networks.filter(n => !n.active && !Nmcli.hasSavedProfile(n.ssid))
    readonly property var details: Nmcli.wirelessDeviceDetails
    spacing: 10

    function signalIcon(strength: int): string {
        return strength > 75 ? "signal_wifi_4_bar" : strength > 50 ? "network_wifi_3_bar" : strength > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }
    function band(frequency: int): string {
        return frequency > 5900 ? "6 GHz" : frequency > 4900 ? "5 GHz" : frequency > 0 ? "2.4 GHz" : "";
    }
    function describe(network: var): string {
        if (errorSsid === network.ssid && errorText) return errorText;
        if (joiningSsid === network.ssid) return qsTr("Joining…");
        return [network.isSecure ? qsTr("Secured") : qsTr("Open"), band(network.frequency)].filter(s => s).join(" · ");
    }
    function refresh(): void {
        Nmcli.loadSavedConnections(() => {});
        Nmcli.getWirelessInterfaces(() => {});
        Nmcli.getNetworks(() => { if (root) root.loading = false; });
        loadTimeout.restart();
    }
    function scan(): void {
        Nmcli.rescanWifi();
        refresh();
    }
    function join(network: var): void {
        if (joiningSsid || network.active) return;
        errorSsid = ""; errorText = ""; confirmForget = "";
        if (passwordSsid && passwordSsid !== network.ssid) passwordSsid = "";
        joiningSsid = network.ssid;
        Nmcli.connectToNetworkWithPasswordCheck(network.ssid, network.isSecure, result => {
            if (!root) return;
            root.joiningSsid = "";
            if (result.needsPassword) root.passwordSsid = network.ssid;
            else if (!result.success) { root.errorSsid = network.ssid; root.errorText = qsTr("Couldn't join this network"); }
        }, network.bssid);
    }
    function joinWithPassword(network: var, password: string): void {
        if (!password || joiningSsid) return;
        errorSsid = ""; errorText = "";
        joiningSsid = network.ssid;
        Nmcli.connectToNetwork(network.ssid, password, network.bssid, result => {
            if (!root) return;
            root.joiningSsid = "";
            if (result.success) root.passwordSsid = "";
            else { root.errorSsid = network.ssid; root.errorText = qsTr("Wrong password or network unavailable"); }
        });
    }
    function forget(ssid: string): void {
        if (confirmForget !== ssid) { confirmForget = ssid; return; }
        confirmForget = "";
        showDetails = false;
        Nmcli.forgetNetwork(ssid, () => { if (root) root.refresh(); });
    }
    function openSettings(): void {
        const index = Nexus.PageRegistry.pages.findIndex(p => p.label === qsTr("Network"));
        Nexus.WindowFactory.create(null, {initialPage: Math.max(0, index)});
        closeRequested();
    }
    onShowDetailsChanged: if (showDetails) Nmcli.getWirelessDeviceDetails("", () => {})
    Component.onCompleted: refresh()
    Keys.onEscapePressed: event => {
        if (passwordSsid) { passwordSsid = ""; event.accepted = true; }
        else event.accepted = false;
    }
    Timer { id: loadTimeout; interval: 8000; onTriggered: root.loading = false }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        IslandButton { iconName: "chevron_left"; implicitWidth: 30; implicitHeight: 30; leftPadding: 5; rightPadding: 5; Accessible.name: qsTr("Back to Control Center"); onClicked: root.backRequested() }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            IslandText { Layout.fillWidth: true; text: "Wi-Fi"; font.pixelSize: 16; font.weight: Font.DemiBold }
            IslandText { Layout.fillWidth: true; elide: Text.ElideRight; text: !Nmcli.wifiEnabled ? qsTr("Off") : Nmcli.scanning || root.loading ? qsTr("Searching…") : root.networks.length === 1 ? qsTr("1 network nearby") : qsTr("%1 networks nearby").arg(root.networks.length); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
        }
        IslandButton {
            visible: Nmcli.wifiEnabled
            implicitWidth: 30; implicitHeight: 30; leftPadding: 5; rightPadding: 5
            enabled: !Nmcli.scanning
            Accessible.name: qsTr("Scan for networks")
            onClicked: root.scan()
            contentItem: Item {
                implicitWidth: 20; implicitHeight: 20
                MaterialIcon { anchors.centerIn: parent; visible: !Nmcli.scanning; text: "refresh"; color: IslandTheme.palette.m3onSurfaceVariant; fontStyle: Tokens.font.icon.small }
                IslandSpinner { anchors.centerIn: parent; running: Nmcli.scanning }
            }
        }
        IslandSwitch { checked: Nmcli.wifiEnabled; Accessible.name: qsTr("Wi-Fi"); onClicked: Nmcli.toggleWifi(() => { if (Nmcli.wifiEnabled) root.scan(); }) }
    }

    // Connected network.
    Rectangle {
        Layout.fillWidth: true
        visible: Nmcli.wifiEnabled && !!root.active
        implicitHeight: hero.implicitHeight + 20
        radius: 18
        color: IslandTheme.palette.card
        border.width: 1
        border.color: IslandTheme.palette.cardBorder
        ColumnLayout {
            id: hero
            x: 10; y: 10; width: parent.width - 20
            spacing: 10
            IslandListRow {
                Layout.fillWidth: true
                leftPadding: 2; rightPadding: 2
                text: root.active?.ssid ?? ""
                subtitle: root.active ? [qsTr("Connected"), root.band(root.active.frequency), `${root.active.strength}%`].filter(s => s).join(" · ") : ""
                iconName: root.signalIcon(root.active?.strength ?? 0)
                active: true
                Accessible.name: qsTr("Show details for %1").arg(text)
                onClicked: root.showDetails = !root.showDetails
                MaterialIcon { text: "expand_more"; rotation: root.showDetails ? 180 : 0; color: IslandTheme.palette.m3onSurfaceVariant; fontStyle: Tokens.font.icon.small; Behavior on rotation { NumberAnimation { duration: 180 * Tokens.anim.durations.scale; easing.type: Easing.OutCubic } } }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6; Layout.rightMargin: 6
                visible: root.showDetails
                columns: 2; columnSpacing: 12; rowSpacing: 4
                DetailLabel { text: qsTr("IP address") } DetailValue { text: root.details?.ipAddress || "—" }
                DetailLabel { text: qsTr("Router") } DetailValue { text: root.details?.gateway || "—" }
                DetailLabel { text: qsTr("Security") } DetailValue { text: root.active?.security || qsTr("None") }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.showDetails
                spacing: 8
                IslandButton { Layout.fillWidth: true; implicitHeight: 32; iconName: "link_off"; text: qsTr("Disconnect"); onClicked: { root.showDetails = false; Nmcli.disconnectFromNetwork(); } }
                IslandButton {
                    Layout.fillWidth: true; implicitHeight: 32
                    iconName: "delete"
                    text: root.confirmForget === root.active?.ssid ? qsTr("Tap again to forget") : qsTr("Forget")
                    onClicked: root.forget(root.active.ssid)
                }
            }
        }
    }

    Flickable {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 292)
        visible: Nmcli.wifiEnabled
        clip: true
        contentHeight: sections.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
        ColumnLayout {
            id: sections
            width: list.width
            spacing: 2
            SectionLabel { visible: root.known.length; text: qsTr("Known networks") }
            Repeater { model: root.known; NetworkRow {} }
            SectionLabel { visible: root.others.length; text: qsTr("Other networks") }
            Repeater { model: root.others; NetworkRow {} }
            IslandText {
                Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 12
                visible: !root.known.length && !root.others.length
                horizontalAlignment: Text.AlignHCenter
                text: root.loading || Nmcli.scanning ? qsTr("Looking for networks…") : qsTr("No other networks found")
                color: IslandTheme.palette.m3outline
                font.pixelSize: 12
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 16; Layout.bottomMargin: 16
        visible: !Nmcli.wifiEnabled
        spacing: 6
        MaterialIcon { Layout.alignment: Qt.AlignHCenter; text: "wifi_off"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.extraLarge }
        IslandText { Layout.alignment: Qt.AlignHCenter; text: qsTr("Wi-Fi is turned off"); font.pixelSize: 13; font.weight: Font.Medium }
        IslandText { Layout.alignment: Qt.AlignHCenter; text: qsTr("Turn it on to see networks around you."); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: IslandTheme.palette.cardBorder }
    IslandButton {
        Layout.fillWidth: true
        implicitHeight: 30
        onClicked: root.openSettings()
        Accessible.name: qsTr("Network settings")
        contentItem: RowLayout {
            IslandText { Layout.fillWidth: true; text: qsTr("Network settings…"); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant }
            MaterialIcon { text: "chevron_right"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.small }
        }
    }

    component SectionLabel: IslandText {
        Layout.fillWidth: true
        Layout.topMargin: 6; Layout.bottomMargin: 2; Layout.leftMargin: 8
        font.pixelSize: 11; font.weight: Font.DemiBold
        color: IslandTheme.palette.m3outline
    }
    component DetailLabel: IslandText { font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
    component DetailValue: IslandText { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 11; elide: Text.ElideMiddle }
    component NetworkRow: ColumnLayout {
        id: networkRow
        required property var modelData
        readonly property bool askingPassword: root.passwordSsid === modelData.ssid
        Layout.fillWidth: true
        spacing: 4
        IslandListRow {
            Layout.fillWidth: true
            text: networkRow.modelData.ssid
            subtitle: root.describe(networkRow.modelData)
            danger: root.errorSsid === networkRow.modelData.ssid && !!root.errorText
            iconName: root.signalIcon(networkRow.modelData.strength)
            busy: root.joiningSsid === networkRow.modelData.ssid
            enabled: !root.joiningSsid || busy
            onClicked: networkRow.askingPassword ? root.passwordSsid = "" : root.join(networkRow.modelData)
            MaterialIcon { visible: networkRow.modelData.isSecure; text: "lock"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.small }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 54; Layout.rightMargin: 4; Layout.bottomMargin: 6
            visible: networkRow.askingPassword
            spacing: 6
            onVisibleChanged: if (visible) password.forceActiveFocus()
            IslandTextField {
                id: password
                Layout.fillWidth: true
                rightPadding: 38
                echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                placeholderText: qsTr("Password")
                Accessible.name: qsTr("Password for %1").arg(networkRow.modelData.ssid)
                onAccepted: joinButton.clicked()
                IslandButton {
                    id: reveal
                    anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 30; implicitHeight: 30; leftPadding: 5; rightPadding: 5
                    checkable: true
                    iconName: checked ? "visibility_off" : "visibility"
                    Accessible.name: checked ? qsTr("Hide password") : qsTr("Show password")
                }
            }
            IslandButton {
                id: joinButton
                text: qsTr("Join"); accent: true; implicitHeight: 38
                enabled: password.text.length >= 8 && !root.joiningSsid
                onClicked: { root.joinWithPassword(networkRow.modelData, password.text); password.clear(); }
            }
        }
    }
}
