import QtQuick
import qs.services

Item {
    id: root

    // Polling runs only while this exists (the Loader drops it when the drawer is gone).
    Component.onCompleted: Resources.viewers++
    Component.onDestruction: Resources.viewers--

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Text {
            text: "Resources"
            color: ResourcesTheme.text
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Text {
            text: Resources.ready ? "RAM " + Math.round(Resources.system.used_kb / 1024) + " MB used" : "Loading…"
            color: ResourcesTheme.textDim
            font.family: ResourcesTheme.numFont
            font.pixelSize: 12
        }
    }
}
