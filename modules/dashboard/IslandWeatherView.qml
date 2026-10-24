pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root
    signal pageRequested(string page)
    readonly property bool ready: !!Weather.cc
    readonly property var today: Weather.forecast.length ? Weather.forecast[0] : null
    readonly property var days: Weather.forecast.slice(0, 5)
    readonly property var hours: Weather.hourlyForecast.slice(0, 24)
    readonly property real rangeMin: days.length ? Math.min(...days.map(d => d.minTempC)) : 0
    readonly property real rangeMax: days.length ? Math.max(...days.map(d => d.maxTempC)) : 1
    property bool timedOut
    readonly property int pageHeight: 448
    implicitHeight: pageHeight
    spacing: 0

    function deg(celsius: var): string {
        if (celsius === undefined || celsius === null) return "--";
        return `${Math.round(GlobalConfig.services.useFahrenheit ? Weather.toFahrenheit(celsius) : celsius)}°`;
    }
    function hourLabel(hour: int): string {
        if (!GlobalConfig.services.useTwelveHourClock) return `${String(hour).padStart(2, "0")}:00`;
        return `${hour % 12 || 12} ${hour < 12 ? "AM" : "PM"}`;
    }
    function dayLabel(entry: var, index: int): string {
        return index === 0 ? qsTr("Today") : new Date(entry.date).toLocaleDateString(Qt.locale(), "ddd");
    }
    function refresh(): void {
        timedOut = false;
        Weather.reload();
        if (Weather.loc) Weather.fetchWeatherData();
    }

    // The service refreshes hourly on its own; opening the page also refreshes
    // when nothing is loaded yet or the first upcoming hour is already >30 min past.
    Component.onCompleted: {
        Weather.reload();
        const first = Weather.hourlyForecast[0];
        const stale = !first || Date.now() - new Date(first.timestamp).getTime() > 30 * 60 * 1000;
        if (Weather.loc && (!ready || stale)) Weather.fetchWeatherData();
    }
    Timer { interval: 15000; running: !root.ready && !root.timedOut; onTriggered: root.timedOut = true }

    // Current conditions
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 120
        visible: root.ready
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                spacing: 4
                MaterialIcon { text: "location_on"; color: IslandTheme.palette.m3onSurfaceVariant; fontStyle: Tokens.font.icon.small }
                IslandText { Layout.fillWidth: true; text: Weather.city || qsTr("Current location"); islandFont: Tokens.font.label.large; color: IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight }
            }
            IslandText { text: root.deg(Weather.cc?.tempC); islandFont: Qt.font({ pixelSize: 52, weight: Font.Light }) }
            IslandText { Layout.fillWidth: true; text: Weather.description; islandFont: Tokens.font.body.medium; elide: Text.ElideRight }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            spacing: 2
            MaterialIcon { Layout.alignment: Qt.AlignRight; text: Weather.icon; color: IslandTheme.palette.m3tertiary; fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.15).build() }
            IslandText { Layout.alignment: Qt.AlignRight; text: qsTr("Feels like %1").arg(root.deg(Weather.cc?.feelsLikeC)); islandFont: Tokens.font.label.medium; color: IslandTheme.palette.m3onSurfaceVariant }
            IslandText { Layout.alignment: Qt.AlignRight; visible: !!root.today; text: qsTr("H %1  L %2").arg(root.deg(root.today?.maxTempC)).arg(root.deg(root.today?.minTempC)); islandFont: Tokens.font.label.medium }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 4
                MaterialIcon { text: "humidity_percentage"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.small }
                IslandText { text: `${Weather.humidity}%`; islandFont: Tokens.font.label.small; color: IslandTheme.palette.m3outline }
                MaterialIcon { text: "air"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.small }
                IslandText { text: qsTr("%1 km/h").arg(Math.round(Weather.windSpeed)); islandFont: Tokens.font.label.small; color: IslandTheme.palette.m3outline }
            }
        }
    }

    Item { Layout.preferredHeight: 16; visible: root.ready }

    // Hourly strip
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 104
        visible: root.ready
        radius: 18
        color: IslandTheme.palette.card
        border.width: 1
        border.color: IslandTheme.palette.cardBorder
        // A horizontal ListView ignores vertical wheel deltas; map them to horizontal scrolling.
        WheelHandler {
            onWheel: event => {
                const delta = event.angleDelta.y || event.angleDelta.x;
                hourly.contentX = Math.max(hourly.originX, Math.min(hourly.originX + hourly.contentWidth - hourly.width, hourly.contentX - delta));
            }
        }
        ListView {
            id: hourly
            anchors.fill: parent
            anchors.margins: 8
            orientation: ListView.Horizontal
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.hours
            delegate: ColumnLayout {
                id: hour
                required property var modelData
                required property int index
                width: 52
                height: hourly.height
                spacing: 2
                IslandText { Layout.alignment: Qt.AlignHCenter; text: hour.index === 0 ? qsTr("Now") : root.hourLabel(hour.modelData.hour); islandFont: Tokens.font.label.small; color: IslandTheme.palette.m3onSurfaceVariant }
                MaterialIcon { Layout.alignment: Qt.AlignHCenter; text: hour.modelData.icon; color: IslandTheme.palette.m3onSurface; fontStyle: Tokens.font.icon.medium }
                IslandText { Layout.alignment: Qt.AlignHCenter; text: root.deg(hour.modelData.tempC); islandFont: Tokens.font.label.large }
                IslandText { Layout.alignment: Qt.AlignHCenter; text: hour.modelData.precipChance >= 20 ? `${hour.modelData.precipChance}%` : " "; islandFont: Tokens.font.label.small; color: IslandTheme.palette.m3tertiary }
            }
        }
    }

    Item { Layout.preferredHeight: 12; visible: root.ready }

    // Five-day forecast with a shared min/max range scale
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 196
        visible: root.ready && root.days.length > 0
        radius: 18
        color: IslandTheme.palette.card
        border.width: 1
        border.color: IslandTheme.palette.cardBorder
        Column {
            anchors.fill: parent
            anchors.margins: 8
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            Repeater {
                model: root.days
                RowLayout {
                    id: dayRow
                    required property var modelData
                    required property int index
                    readonly property real span: Math.max(1, root.rangeMax - root.rangeMin)
                    width: parent.width
                    height: 36
                    spacing: 10
                    IslandText { Layout.preferredWidth: 58; text: root.dayLabel(dayRow.modelData, dayRow.index); islandFont: Tokens.font.label.large; elide: Text.ElideRight }
                    MaterialIcon { Layout.preferredWidth: 28; text: dayRow.modelData.icon; color: IslandTheme.palette.m3onSurface; fontStyle: Tokens.font.icon.medium }
                    IslandText { Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight; text: root.deg(dayRow.modelData.minTempC); islandFont: Tokens.font.label.large; color: IslandTheme.palette.m3onSurfaceVariant }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 5
                        radius: height / 2
                        color: IslandTheme.palette.track
                        Rectangle {
                            x: parent.width * (dayRow.modelData.minTempC - root.rangeMin) / dayRow.span
                            width: Math.max(height, parent.width * (dayRow.modelData.maxTempC - dayRow.modelData.minTempC) / dayRow.span)
                            height: parent.height
                            radius: height / 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: IslandTheme.palette.m3tertiary }
                                GradientStop { position: 1; color: IslandTheme.palette.warning }
                            }
                        }
                        // Current temperature marker on today's bar
                        Rectangle {
                            visible: dayRow.index === 0 && Weather.cc?.tempC !== undefined
                            width: 9; height: 9; radius: 4.5
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width * Math.max(0, Math.min(1, ((Weather.cc?.tempC ?? 0) - root.rangeMin) / dayRow.span)) - width / 2
                            color: IslandTheme.palette.m3onSurface
                            border.width: 2
                            border.color: IslandTheme.palette.card
                        }
                    }
                    IslandText { Layout.preferredWidth: 34; text: root.deg(dayRow.modelData.maxTempC); islandFont: Tokens.font.label.large }
                }
            }
        }
    }

    // Loading / unavailable (same height as the ready layout, so the page does not jump)
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: root.width
        Layout.preferredHeight: root.pageHeight
        visible: !root.ready
        spacing: 10
        Item { Layout.fillHeight: true }
        MaterialIcon { Layout.alignment: Qt.AlignHCenter; text: root.timedOut ? "cloud_off" : "cloud_sync"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.4).build() }
        IslandText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 320
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: !root.timedOut ? qsTr("Loading weather…") : Weather.loc ? qsTr("Weather is unavailable right now") : qsTr("Couldn't determine your location. Set a weather location in settings or try again.")
            color: IslandTheme.palette.m3onSurfaceVariant
        }
        IslandButton { Layout.alignment: Qt.AlignHCenter; visible: root.timedOut; iconName: "refresh"; text: qsTr("Try again"); onClicked: root.refresh() }
        Item { Layout.fillHeight: true }
    }

}
