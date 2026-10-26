pragma ComponentBehavior: Bound
import QtQuick
import qs.services

// Hover peek when nothing is happening: the time, the date and the battery.
Item {
    implicitHeight: 52
    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 2
        IslandText { text: Time.timeStr; font.pixelSize: 30; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
        IslandText { text: Time.format("dddd, MMMM d"); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant }
    }
    IslandBattery {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 4
    }
}
