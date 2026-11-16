import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root

    // Polling runs only while this exists (the Loader drops it when the drawer is gone).
    Component.onCompleted: Resources.viewers++
    Component.onDestruction: Resources.viewers--

    implicitHeight: layout.implicitHeight + 40

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // Only the visible tab exists, so each tab polls only while it is on screen.
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: page.implicitHeight
            clip: true
            contentWidth: width
            contentHeight: page.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: page

                // A new page eases in: fade plus a small springy scale, like the island's content swap.
                onLoaded: appear.restart()

                width: flick.width
                transformOrigin: Item.Bottom
                sourceComponent: tabs.current === "processes" ? processes : tabs.current === "agents" ? agents : tabs.current === "dev" ? dev : tabs.current === "system" ? system : overview
            }
        }

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
    }

    // Result of the last Stop.
    Rectangle {
        visible: ResourcesActions.status !== ""
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 76
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

    ParallelAnimation {
        id: appear

        NumberAnimation {
            target: page
            property: "opacity"
            from: 0
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: page
            property: "scale"
            from: 0.97
            to: 1
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.4
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
