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
    signal pageRequested(string page)
    readonly property date selectedMonth: screenState.dashboardDate
    property date selectedDay: new Date()
    readonly property bool selectedIsToday: CalendarNotes.key(selectedDay) === CalendarNotes.key(new Date())
    readonly property string memorySummary: {
        const fmt = UsageFmt.formatKib(Memory.used, Memory.total);
        return `${+fmt.value.toFixed(1)} / ${+fmt.total.toFixed(1)} ${fmt.unit}`;
    }
    readonly property string diskSummary: {
        if (!Storage.primaryDisk) return qsTr("No disks detected");
        const fmt = UsageFmt.formatKib(Storage.primaryDisk.used, Storage.primaryDisk.total);
        return `${+fmt.value.toFixed(1)} / ${+fmt.total.toFixed(1)} ${fmt.unit}`;
    }
    implicitHeight: 330 + powerProfiles.implicitHeight + 12 + (IslandHealth.warning ? 60 : 0)

    function loadNote(): void {
        noteField.text = CalendarNotes.noteFor(selectedDay);
    }
    function commitNote(): void {
        CalendarNotes.setNote(selectedDay, noteField.text);
    }
    function selectDay(day: date): void {
        commitNote();
        selectedDay = day;
        loadNote();
    }

    Component.onCompleted: { Weather.reload(); loadNote(); }
    Component.onDestruction: commitNote()
    Connections {
        target: CalendarNotes
        function onNotesChanged(): void { if (!noteField.activeFocus) root.loadNote(); }
    }

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
                    // Built from the local y/m/d so QDate -> JS Date timezone shifts cannot move the day.
                    readonly property date localDate: new Date(model.year, model.month, model.day)
                    readonly property string key: CalendarNotes.key(localDate)
                    readonly property bool selected: key === CalendarNotes.key(root.selectedDay)
                    readonly property bool hasNote: !!CalendarNotes.notes[key]
                    Accessible.role: Accessible.Button
                    Accessible.name: localDate.toLocaleDateString(Qt.locale(), Locale.LongFormat) + (hasNote ? qsTr(", has a note") : "")
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectDay(day.localDate) }
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2
                        height: width
                        radius: height / 2
                        visible: day.model.today || day.selected
                        color: day.model.today ? IslandTheme.palette.m3primary : "transparent"
                        border.width: day.selected && !day.model.today ? 1 : 0
                        border.color: IslandTheme.palette.m3outline
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: 4; height: 4; radius: 2
                        visible: day.hasNote
                        color: day.model.today ? IslandTheme.palette.m3onSurfaceVariant : IslandTheme.palette.m3tertiary
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

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                IslandText {
                    Layout.preferredWidth: 52
                    text: root.selectedIsToday ? qsTr("Today") : root.selectedDay.toLocaleDateString(Qt.locale(), "MMM d")
                    islandFont: Tokens.font.label.medium
                    color: IslandTheme.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
                IslandTextField {
                    id: noteField
                    Layout.fillWidth: true
                    maximumLength: CalendarNotes.maximumLength
                    placeholderText: qsTr("Add a note…")
                    Accessible.name: qsTr("Note for %1").arg(root.selectedDay.toLocaleDateString(Qt.locale(), Locale.LongFormat))
                    onEditingFinished: root.commitNote()
                    Keys.onEscapePressed: { root.loadNote(); focus = false; }
                }
                IslandButton {
                    visible: noteField.text.length > 0
                    iconName: "delete"
                    Accessible.name: qsTr("Delete note")
                    onClicked: { noteField.text = ""; root.commitNote(); }
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

            IslandButton {
                id: weatherGlance
                Layout.fillWidth: true
                implicitHeight: 40
                Accessible.name: Weather.cc ? qsTr("Weather: %1, %2. Open forecast").arg(Weather.temp).arg(Weather.description) : qsTr("Open weather")
                onClicked: root.pageRequested("weather")
                background: Rectangle {
                    radius: 14
                    color: weatherGlance.hovered ? IslandTheme.palette.cardHover : IslandTheme.palette.card
                    border.width: weatherGlance.activeFocus ? 2 : 0
                    border.color: IslandTheme.palette.focus
                }
                contentItem: RowLayout {
                    spacing: 8
                    MaterialIcon { text: Weather.icon; color: IslandTheme.palette.m3tertiary; fontStyle: Tokens.font.icon.small }
                    IslandText { text: Weather.cc ? Weather.temp : "--"; islandFont: Tokens.font.label.large }
                    IslandText { Layout.fillWidth: true; text: Weather.cc ? Weather.description : qsTr("Weather"); islandFont: Tokens.font.label.small; color: IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight }
                    MaterialIcon { text: "chevron_right"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.small }
                }
            }

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
