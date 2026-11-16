import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root

    // Polling runs only while this exists (the Loader drops it when the drawer is gone).
    Component.onCompleted: Resources.viewers++
    Component.onDestruction: Resources.viewers--

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Text {
            text: "Resources"
            color: ResourcesTheme.text
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Summary {
            Layout.fillWidth: true
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: ResourcesTheme.border
        }
        GroupList {
            Layout.fillWidth: true
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: ResourcesTheme.border
        }
        AgentList {
            Layout.fillWidth: true
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
