import QtQuick
import QtQuick.Layouts
import qs.services
import "../dashboard/helpers/ResourceLogic.js" as Logic

// Hardware that is not memory: GPU clock, disk, network. Everything here polls only while the tab exists.
ColumnLayout {
    id: root

    property var down: []
    property var up: []
    readonly property var gpu: ResourcesSystem.gpu
    readonly property var disk: ResourcesSystem.disk
    readonly property real diskFrac: Logic.fraction(disk.used_kb, disk.total_kb)

    spacing: 10

    Component.onCompleted: {
        ResourcesSystem.viewers++;
        NetworkUsage.refCount++;
    }
    Component.onDestruction: {
        ResourcesSystem.viewers--;
        NetworkUsage.refCount--;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.down = Logic.ring(root.down, NetworkUsage.downloadSpeed, 60);
            root.up = Logic.ring(root.up, NetworkUsage.uploadSpeed, 60);
        }
    }

    Card {
        Layout.fillWidth: true
        title: "GPU clock"
        trailing: root.gpu ? root.gpu.cur_mhz + " / " + root.gpu.max_mhz + " MHz" : (ResourcesSystem.ready ? "Not available" : "—")

        ProgressBar {
            visible: root.gpu !== null
            Layout.fillWidth: true
            value: root.gpu ? Logic.fraction(root.gpu.cur_mhz, root.gpu.max_mhz) : 0
            tint: ResourcesTheme.teal
        }
        Text {
            visible: root.gpu !== null
            text: "Clock speed, not utilisation"
            color: ResourcesTheme.textTertiary
            font.family: ResourcesTheme.uiFont
            font.pixelSize: 11
        }
    }

    Card {
        Layout.fillWidth: true
        title: "Disk"
        trailing: ResourcesSystem.ready ? Logic.formatKb(root.disk.used_kb) + " / " + Logic.formatKb(root.disk.total_kb) : "—"

        ProgressBar {
            Layout.fillWidth: true
            value: root.diskFrac
            tint: root.diskFrac >= 0.9 ? ResourcesTheme.hot : root.diskFrac >= 0.8 ? ResourcesTheme.warm : ResourcesTheme.blue
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Read " + Logic.formatRate(root.disk.read_bps)
                color: ResourcesTheme.textDim
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 12
                font.features: ({"tnum": 1})
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: "Write " + Logic.formatRate(root.disk.write_bps)
                color: ResourcesTheme.textDim
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 12
                font.features: ({"tnum": 1})
            }
        }
    }

    MetricCard {
        Layout.fillWidth: true
        title: "Download"
        value: Logic.formatRate(NetworkUsage.downloadSpeed)
        values: root.down
        ceiling: Math.max(1024, ...root.down)
        tint: ResourcesTheme.blue
    }
    MetricCard {
        Layout.fillWidth: true
        title: "Upload"
        value: Logic.formatRate(NetworkUsage.uploadSpeed)
        values: root.up
        ceiling: Math.max(1024, ...root.up)
        tint: ResourcesTheme.purple
    }
}
