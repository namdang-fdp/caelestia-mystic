import QtQuick
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Rectangle {
    id: root
    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool plugged: !UPower.onBattery
    readonly property int percentage: Math.round(UPower.displayDevice.percentage * 100)
    readonly property color chargingColour: "#8cdea9"
    readonly property color middleColour: "#f2c66d"
    readonly property color statusColour: plugged ? chargingColour : percentage >= 60 ? chargingColour : percentage >= 25 ? middleColour : IslandTheme.palette.m3error
    visible: UPower.displayDevice.isLaptopBattery
    implicitWidth: contents.implicitWidth + 16
    implicitHeight: 28
    radius: height / 2
    color: Qt.alpha(statusColour, 0.13)
    Accessible.name: qsTr("Battery %1 percent, %2").arg(percentage).arg(charging ? qsTr("charging") : plugged ? qsTr("plugged in") : qsTr("on battery"))
    Row {
        id: contents
        anchors.centerIn: parent
        spacing: 4
        MaterialIcon {
            text: root.plugged ? root.charging ? "bolt" : "power" : Icons.getBatteryIcon(UPower.displayDevice.percentage)
            color: root.statusColour
            fontStyle: Tokens.font.icon.small
        }
        IslandText {
            text: `${root.percentage}%`
            color: root.statusColour
            islandFont: Tokens.font.label.medium
        }
    }
}
