import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Panels")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        NavRow {
            first: true
            icon: "dashboard"
            label: qsTr("Dynamic Island")
            status: Config.dashboard.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            icon: "call_to_action"
            label: qsTr("Dock")
            status: DockConfig.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: root.nState.openSubPage(10)
        }

        NavRow {
            last: true
            icon: "apps"
            label: qsTr("Launcher")
            status: Config.launcher.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: root.nState.openSubPage(3)
        }

    }
}
