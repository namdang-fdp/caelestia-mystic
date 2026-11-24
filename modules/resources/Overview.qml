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

    // Memory: the headline. A ring, the number, how worried to be, and its recent history.
    Card {
        id: memory

        readonly property color tint: ResourcesTheme.tone(Logic.severity("ram", ResourcesHistory.ramFrac))
        readonly property var range: Logic.autoRange(ResourcesHistory.ram, 6, 100)

        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Item {
                implicitWidth: 76
                implicitHeight: 76
                RingGauge {
                    anchors.fill: parent
                    value: ResourcesHistory.ramFrac
                    tint: memory.tint
                }
                Text {
                    anchors.centerIn: parent
                    text: Math.round(ResourcesHistory.ramFrac * 100) + "%"
                    color: ResourcesTheme.text
                    font.family: ResourcesTheme.uiFont
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    font.features: ({"tnum": 1})
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: "Memory"
                    color: ResourcesTheme.textDim
                    font.family: ResourcesTheme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                RowLayout {
                    spacing: 6
                    Text {
                        text: ResourcesHistory.ready ? Logic.formatKb(ResourcesHistory.usedKb) : "—"
                        color: ResourcesTheme.text
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        font.features: ({"tnum": 1})
                    }
                    Text {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 4
                        text: ResourcesHistory.ready ? "of " + Logic.formatKb(ResourcesHistory.totalKb) : ""
                        color: ResourcesTheme.textDim
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 13
                        font.features: ({"tnum": 1})
                    }
                }
                RowLayout {
                    spacing: 6
                    Rectangle {
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: memory.tint
                    }
                    Text {
                        text: Logic.pressureLabel(ResourcesHistory.ramFrac) + " pressure"
                        color: ResourcesTheme.textDim
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 12
                    }
                }
            }
        }
        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            values: ResourcesHistory.ram
            tint: memory.tint
            floor: memory.range.floor
            ceiling: memory.range.ceiling
        }
    }

    // CPU and swap side by side.
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        StatCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "CPU"
            value: Math.round(root.cpuNow) + "%"
            detail: root.temperature >= 0 ? Math.round(root.temperature) + "°C" : " "
            values: ResourcesHistory.cpu
            minSpan: 10
            tint: ResourcesTheme.tone(Logic.severity("cpu", root.cpuNow / 100))
        }
        StatCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: "Swap"
            value: ResourcesHistory.ready ? Logic.formatKb(ResourcesHistory.swapUsedKb) : "—"
            detail: ResourcesHistory.ready ? "of " + Logic.formatKb(ResourcesHistory.swapTotalKb) : " "
            values: ResourcesHistory.swap
            minSpan: 4
            tint: ResourcesTheme.tone(Logic.severity("swap", ResourcesHistory.swapFrac))
        }
    }

    // Network: one compact row.
    Card {
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "↓"
                color: ResourcesTheme.blue
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 15
                font.weight: Font.Bold
            }
            Text {
                text: root.rate(NetworkUsage.downloadSpeed)
                color: ResourcesTheme.text
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 13
                font.features: ({"tnum": 1})
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: "↑"
                color: ResourcesTheme.purple
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 15
                font.weight: Font.Bold
            }
            Text {
                text: root.rate(NetworkUsage.uploadSpeed)
                color: ResourcesTheme.text
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 13
                font.features: ({"tnum": 1})
            }
        }
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
