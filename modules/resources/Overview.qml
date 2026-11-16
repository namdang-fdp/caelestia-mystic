import QtQuick
import QtQuick.Layouts
import qs.services
import "../dashboard/helpers/ResourceLogic.js" as Logic

// "Is my machine OK": memory, CPU and swap with ten minutes of history, network, and one banner
// when something needs attention.
ColumnLayout {
    id: root

    signal goto(string tab)

    readonly property var attention: Logic.attention({ ram: ResourcesHistory.ramFrac, swap: ResourcesHistory.swapFrac }, Logic.agentRows(Resources.claude, AgentState.live, Resources.groups))
    readonly property real cpuNow: ResourcesHistory.cpu.length ? ResourcesHistory.cpu[ResourcesHistory.cpu.length - 1] : 0
    readonly property real temperature: IslandHealth.temperature

    function rate(bytes: real): string {
        const r = NetworkUsage.formatBytes(bytes);
        return (r.value >= 100 ? Math.round(r.value) : r.value.toFixed(1)) + " " + r.unit;
    }

    spacing: 10

    // Shared network sampling runs only while this page exists.
    Component.onCompleted: NetworkUsage.refCount++
    Component.onDestruction: NetworkUsage.refCount--

    Rectangle {
        visible: root.attention !== null
        Layout.fillWidth: true
        implicitHeight: banner.implicitHeight + 20
        radius: ResourcesTheme.radiusCard
        color: ResourcesTheme.card

        RowLayout {
            id: banner
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            IconTile {
                icon: "warning"
                tint: root.attention ? ResourcesTheme.tone(root.attention.level) : ResourcesTheme.warm
            }
            Text {
                Layout.fillWidth: true
                text: root.attention ? root.attention.text : ""
                wrapMode: Text.WordWrap
                color: ResourcesTheme.text
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 13
            }
            Rectangle {
                implicitWidth: viewLabel.implicitWidth + 20
                implicitHeight: 26
                radius: ResourcesTheme.radiusControl
                color: viewArea.containsMouse ? ResourcesTheme.separator : ResourcesTheme.track
                Text {
                    id: viewLabel
                    anchors.centerIn: parent
                    text: "View"
                    color: ResourcesTheme.text
                    font.family: ResourcesTheme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: viewArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.attention) root.goto(root.attention.tab)
                }
            }
        }
    }

    MetricCard {
        Layout.fillWidth: true
        title: "Memory"
        value: ResourcesHistory.ready ? Logic.formatKb(ResourcesHistory.usedKb) + " / " + Logic.formatKb(ResourcesHistory.totalKb) : "—"
        values: ResourcesHistory.ram
        tint: ResourcesTheme.tone(Logic.severity("ram", ResourcesHistory.ramFrac))
    }
    MetricCard {
        Layout.fillWidth: true
        title: "CPU"
        value: Math.round(root.cpuNow) + "%"
        detail: root.temperature >= 0 ? Math.round(root.temperature) + "°C" : ""
        values: ResourcesHistory.cpu
        tint: ResourcesTheme.tone(Logic.severity("cpu", root.cpuNow / 100))
    }
    MetricCard {
        Layout.fillWidth: true
        title: "Swap"
        value: ResourcesHistory.ready ? Logic.formatKb(ResourcesHistory.swapUsedKb) + " / " + Logic.formatKb(ResourcesHistory.swapTotalKb) : "—"
        values: ResourcesHistory.swap
        tint: ResourcesTheme.tone(Logic.severity("swap", ResourcesHistory.swapFrac))
    }
    Card {
        Layout.fillWidth: true
        title: "Network"
        trailing: "↓ " + root.rate(NetworkUsage.downloadSpeed) + "   ↑ " + root.rate(NetworkUsage.uploadSpeed)
    }

    Card {
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            IconTile {
                icon: "notifications"
                tint: ResourcesTheme.warm
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: "Memory alerts"
                    color: ResourcesTheme.text
                    font.family: ResourcesTheme.uiFont
                    font.pixelSize: 13
                }
                Text {
                    text: "Notify once when memory or swap stays high"
                    color: ResourcesTheme.textDim
                    font.family: ResourcesTheme.uiFont
                    font.pixelSize: 11
                }
            }
            Toggle {
                checked: ResourcesAlerts.enabled
                onToggled: ResourcesAlerts.setEnabled(!ResourcesAlerts.enabled)
            }
        }
    }
}
