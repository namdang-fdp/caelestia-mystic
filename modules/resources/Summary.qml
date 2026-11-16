import QtQuick
import QtQuick.Layouts
import qs.services
import "../dashboard/helpers/ResourceLogic.js" as Logic

// RAM / swap / CPU at a glance. Colours follow ResourceLogic.severity.
ColumnLayout {
    id: root

    readonly property var sys: Resources.system
    readonly property real ramFrac: Logic.fraction(sys.used_kb, sys.total_kb)
    readonly property real swapFrac: Logic.fraction(sys.swap_used_kb, sys.swap_total_kb)
    readonly property real cpuFrac: (sys.cpu_percent ?? 0) / 100
    readonly property real temperature: IslandHealth.temperature

    function tone(level: string): color {
        return level === "hot" ? ResourcesTheme.hot : level === "warm" ? ResourcesTheme.warm : ResourcesTheme.ok;
    }

    spacing: 10

    // Memory with a thin bar.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Memory"
                color: ResourcesTheme.textDim
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 13
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Resources.ready ? Logic.formatKb(root.sys.used_kb) + " / " + Logic.formatKb(root.sys.total_kb) : "—"
                color: ResourcesTheme.text
                font.family: ResourcesTheme.numFont
                font.pixelSize: 13
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: ResourcesTheme.track
            Rectangle {
                width: parent.width * Math.min(1, root.ramFrac)
                height: parent.height
                radius: 2
                color: root.tone(Logic.severity("ram", root.ramFrac))
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "Swap"
            color: ResourcesTheme.textDim
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 13
        }
        Item { Layout.fillWidth: true }
        Text {
            text: Resources.ready ? Logic.formatKb(root.sys.swap_used_kb) + " / " + Logic.formatKb(root.sys.swap_total_kb) : "—"
            color: root.tone(Logic.severity("swap", root.swapFrac))
            font.family: ResourcesTheme.numFont
            font.pixelSize: 13
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "CPU"
            color: ResourcesTheme.textDim
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 13
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: root.temperature >= 0
            text: Math.round(root.temperature) + "°C"
            color: ResourcesTheme.textDim
            font.family: ResourcesTheme.numFont
            font.pixelSize: 13
        }
        Text {
            text: Resources.ready ? Math.round(root.sys.cpu_percent) + "%" : "—"
            color: root.tone(Logic.severity("cpu", root.cpuFrac))
            font.family: ResourcesTheme.numFont
            font.pixelSize: 13
            Layout.leftMargin: 8
        }
    }
}
