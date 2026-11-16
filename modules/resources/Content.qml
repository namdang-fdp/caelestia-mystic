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
        spacing: 14

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

        // Only the visible tab exists, so each tab polls only while it is on screen.
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: page.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: page
                width: flick.width
                sourceComponent: tabs.current === "processes" ? processes : tabs.current === "agents" ? agents : tabs.current === "dev" ? dev : tabs.current === "system" ? system : overview
            }
        }
    }

    // Result of the last Stop.
    Rectangle {
        visible: ResourcesActions.status !== ""
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: statusText.implicitWidth + 24
        implicitHeight: 28
        radius: 14
        color: ResourcesTheme.separator

        Text {
            id: statusText
            anchors.centerIn: parent
            text: ResourcesActions.status
            color: ResourcesTheme.text
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 12
        }
    }

    Component {
        id: overview
        Overview {
            onGoto: tab => tabs.current = tab
        }
    }
    Component {
        id: processes
        GroupList {}
    }
    Component {
        id: agents
        AgentList {}
    }
    Component {
        id: dev
        DevTab {}
    }
    Component {
        id: system
        SystemTab {}
    }
}
