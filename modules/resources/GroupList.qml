import QtQuick
import QtQuick.Layouts
import qs.services
import "../dashboard/helpers/ResourceLogic.js" as Logic

// Processes grouped by app, top 8, sortable by RAM or CPU.
ColumnLayout {
    id: root

    property string sortKey: "ram"
    readonly property var rows: Logic.sortGroups(Resources.groups, sortKey).slice(0, 8)

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "PROCESSES"
            color: ResourcesTheme.textDim
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 11
            font.letterSpacing: 0.6
        }
        Item { Layout.fillWidth: true }
        SortToggle {
            key: root.sortKey
            onChanged: key => root.sortKey = key
        }
    }

    Repeater {
        model: root.rows

        RowLayout {
            id: row

            required property var modelData

            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: row.modelData.name
                elide: Text.ElideRight
                color: ResourcesTheme.text
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 13
            }
            Text {
                text: row.modelData.count + "p"
                color: ResourcesTheme.textDim
                font.family: ResourcesTheme.numFont
                font.pixelSize: 11
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
            Text {
                text: Math.round(row.modelData.cpu_percent) + "%"
                color: root.sortKey === "cpu" ? ResourcesTheme.text : ResourcesTheme.textDim
                font.family: ResourcesTheme.numFont
                font.pixelSize: 12
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }
            Text {
                text: Logic.formatKb(row.modelData.ram_kb)
                color: root.sortKey === "ram" ? ResourcesTheme.text : ResourcesTheme.textDim
                font.family: ResourcesTheme.numFont
                font.pixelSize: 12
                Layout.preferredWidth: 64
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
