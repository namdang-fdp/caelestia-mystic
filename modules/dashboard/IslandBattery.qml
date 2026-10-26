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
    visible: UPower.displayDevice.isLaptopBattery
    implicitWidth: contents.implicitWidth
    implicitHeight: 28
    radius: height / 2
    color: "transparent"
    Accessible.name: qsTr("Battery %1 percent, %2").arg(percentage).arg(charging ? qsTr("charging") : plugged ? qsTr("plugged in") : qsTr("on battery"))
    Row {
        id: contents
        anchors.centerIn: parent
        spacing: 6
        IslandText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${root.percentage}%`
            color: !root.plugged && root.percentage < 20 ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurface
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        IslandBatteryGlyph {
            anchors.verticalCenter: parent.verticalCenter
            level: UPower.displayDevice.percentage
            charging: root.charging
            plugged: root.plugged
        }
    }
}
