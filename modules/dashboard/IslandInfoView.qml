pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root
    required property ScreenState screenState
    readonly property date selectedMonth: screenState.dashboardDate
    readonly property string memorySummary: {
        const fmt = UsageFmt.formatKib(Memory.used, Memory.total);
        return `${+fmt.value.toFixed(1)} / ${+fmt.total.toFixed(1)} ${fmt.unit}`;
    }
    readonly property string diskSummary: {
        if (!Storage.primaryDisk) return qsTr("No disks detected");
        const fmt = UsageFmt.formatKib(Storage.primaryDisk.used, Storage.primaryDisk.total);
        return `${+fmt.value.toFixed(1)} / ${+fmt.total.toFixed(1)} ${fmt.unit}`;
    }
    implicitHeight: 278 + powerProfiles.implicitHeight + 12 + (IslandHealth.warning ? 60 : 0)

    function changeMonth(offset: int): void {
        screenState.dashboardDate = new Date(selectedMonth.getFullYear(), selectedMonth.getMonth() + offset, 1);
    }

    // Existing sampled services run only while this pane is mounted.
    ServiceRef { service: Cpu }
    ServiceRef { service: Memory }
    ServiceRef { service: Storage }

    Rectangle {
        id: warningBanner
        width: parent.width
        height: IslandHealth.warning ? 48 : 0
        visible: IslandHealth.warning
        radius: 16
        color: Qt.alpha(IslandTheme.palette.m3error, .12)
        RowLayout {
            anchors.fill: parent; anchors.margins: 10
            MaterialIcon { text: IslandHealth.icon; color: IslandTheme.palette.m3error; fontStyle: Tokens.font.icon.small }
            IslandText { Layout.fillWidth: true; text: IslandHealth.label + (IslandHealth.batteryWarning ? qsTr(" · Connect your charger") : qsTr(" · Consider a cooler power profile")); elide: Text.ElideRight; color: IslandTheme.palette.m3onSurface }
        }
    }
    RowLayout {
        anchors.fill: parent
        anchors.topMargin: warningBanner.visible ? 60 : 0
        spacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                IslandButton { iconName: "chevron_left"; Accessible.name: qsTr("Previous month"); onClicked: root.changeMonth(-1) }
                IslandButton {
                    Layout.fillWidth: true
                    text: calendar.title
                    Accessible.name: qsTr("%1, return to current month").arg(calendar.title)
                    onClicked: root.screenState.dashboardDate = root.Time.date
                }
                IslandButton { iconName: "chevron_right"; Accessible.name: qsTr("Next month"); onClicked: root.changeMonth(1) }
            }

            DayOfWeekRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                locale: calendar.locale
                delegate: IslandText {
                    required property var model
                    text: model.narrowName
                    horizontalAlignment: Text.AlignHCenter
                    islandFont: Tokens.font.label.small
                    color: IslandTheme.palette.m3onSurfaceVariant
                }
            }

            MonthGrid {
                id: calendar
                Layout.fillWidth: true
                Layout.fillHeight: true
                month: root.selectedMonth.getMonth()
                year: root.selectedMonth.getFullYear()
                locale: Qt.locale()
                spacing: 2
                delegate: Item {
                    id: day
                    required property var model
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2
                        height: width
                        radius: height / 2
                        visible: day.model.today
                        color: IslandTheme.palette.m3primary
                    }
                    IslandText {
                        anchors.centerIn: parent
                        text: day.model.day
                        islandFont: Tokens.font.body.small
                        opacity: day.model.month === calendar.month ? 1 : 0.35
                        color: day.model.today ? IslandTheme.palette.m3onPrimary : IslandTheme.palette.m3onSurface
                    }
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Qt.alpha(IslandTheme.palette.m3outline, 0.16)
        }

        ColumnLayout {
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            spacing: 12

            Metric {
                iconName: "memory"
                label: qsTr("CPU")
                value: Cpu.percentage
                detail: Cpu.temperature > 0 ? `${Math.round(Cpu.temperature)}°C` : qsTr("Processor usage")
                accent: IslandTheme.palette.m3primary
            }
            Metric {
                iconName: "memory_alt"
                label: qsTr("RAM")
                value: Memory.percentage
                detail: root.memorySummary
                accent: IslandTheme.palette.m3tertiary
            }
            Metric {
                iconName: "hard_drive"
                label: qsTr("Disk")
                value: Storage.primaryDisk?.perc ?? 0
                detail: root.diskSummary
                accent: IslandTheme.palette.m3secondary
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                visible: UPower.displayDevice.isLaptopBattery
                IslandBattery { id: battery }
                IslandText {
                    Layout.fillWidth: true
                    text: battery.charging ? qsTr("Charging") : battery.plugged ? qsTr("Plugged in") : qsTr("On battery")
                    islandFont: Tokens.font.label.small
                    color: battery.plugged ? battery.chargingColour : IslandTheme.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }
            IslandPowerProfiles {
                id: powerProfiles
                Layout.fillWidth: true
            }
        }
    }

    component Metric: ColumnLayout {
        id: metric
        required property string iconName
        required property string label
        required property real value
        required property string detail
        required property color accent
        Layout.fillWidth: true
        spacing: 7
        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: metric.iconName; color: metric.accent; fontStyle: Tokens.font.icon.small }
            IslandText { text: metric.label; islandFont: Tokens.font.label.medium }
            Item { Layout.fillWidth: true }
            IslandText { text: `${Math.round(metric.value * 100)}%`; islandFont: Tokens.font.title.medium; color: metric.accent }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 5
            radius: height / 2
            color: Qt.alpha(metric.accent, 0.14)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, metric.value))
                height: parent.height
                radius: height / 2
                color: metric.accent
                Behavior on width { NumberAnimation { duration: 350 * Tokens.anim.durations.scale; easing.type: Easing.OutCubic } }
            }
        }
        IslandText {
            Layout.fillWidth: true
            text: metric.detail
            islandFont: Tokens.font.label.small
            color: IslandTheme.palette.m3onSurfaceVariant
            elide: Text.ElideRight
        }
    }
}
