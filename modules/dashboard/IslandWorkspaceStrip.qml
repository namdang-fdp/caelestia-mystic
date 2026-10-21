pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Row {
    id: root
    required property ShellScreen screen
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property int startId: Math.floor((activeId - 1) / 6) * 6 + 1
    signal overviewRequested
    spacing: 4
    Repeater {
        model: 6
        IslandButton {
            required property int index
            readonly property int workspaceId: root.startId + index
            text: workspaceId.toString()
            implicitWidth: 34
            checked: root.activeId === workspaceId
            Accessible.name: qsTr("Switch to workspace %1").arg(workspaceId)
            onClicked: IslandWorkspaces.activate(workspaceId)
        }
    }
    IslandButton {
        iconName: "grid_view"
        Accessible.name: qsTr("Workspace overview")
        onClicked: root.overviewRequested()
    }
}
