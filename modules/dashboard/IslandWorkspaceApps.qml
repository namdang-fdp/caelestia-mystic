pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services
import qs.utils

Row {
    id: root
    required property var apps
    property int maximumIcons: 4
    property int iconSize: 16
    readonly property int overflow: Math.max(0, apps.length - maximumIcons)
    spacing: 5

    Repeater {
        model: ScriptModel { values: root.apps.slice(0, root.maximumIcons) }
        Item {
            id: app
            required property string modelData
            readonly property DesktopEntry entry: Dock.entryFor(modelData)
            readonly property string icon: entry?.icon || modelData
            width: root.iconSize
            height: root.iconSize
            Accessible.role: Accessible.Graphic
            Accessible.name: entry?.name || modelData

            IconImage {
                id: iconImage
                anchors.fill: parent
                source: app.icon.startsWith("/") || app.icon.startsWith("file://")
                    ? Icons.notificationIcon(app.icon) : Quickshell.iconPath(app.icon, true)
                visible: status === Image.Ready
            }
            MaterialIcon {
                anchors.centerIn: parent
                visible: !iconImage.visible
                text: Icons.getAppCategoryIcon(app.modelData, "web_asset")
                font.pixelSize: root.iconSize
                color: IslandTheme.palette.m3onSurfaceVariant
            }
        }
    }
    IslandText {
        visible: root.overflow > 0
        anchors.verticalCenter: parent.verticalCenter
        text: `+${root.overflow}`
        font.pixelSize: 11
        font.weight: Font.Medium
        color: IslandTheme.palette.m3onSurfaceVariant
        Accessible.name: qsTr("%1 more apps").arg(root.overflow)
    }
}
