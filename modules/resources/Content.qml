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

        TabBar {
            id: tabs
            Layout.fillWidth: true
            current: "overview"
            tabs: [
                { id: "overview", icon: "speed", tint: ResourcesTheme.blue, label: "Overview" },
                { id: "processes", icon: "format_list_bulleted", tint: ResourcesTheme.warm, label: "Processes" },
                { id: "agents", icon: "auto_awesome", tint: ResourcesTheme.purple, label: "Agents" },
                { id: "dev", icon: "terminal", tint: ResourcesTheme.ok, label: "Dev" },
                { id: "system", icon: "memory", tint: ResourcesTheme.teal, label: "System" }
            ]
            onPicked: id => current = id
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
