pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Caelestia.Config
import qs.components
import qs.services

// Countdown / Pomodoro page. State lives in IslandTimer so the countdown keeps
// running as a live activity in the compact pill.
ColumnLayout {
    id: root
    signal backRequested
    property int customMinutes: 20
    readonly property bool active: IslandTimer.active
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        IslandButton { iconName: "chevron_left"; implicitWidth: 30; implicitHeight: 30; leftPadding: 5; rightPadding: 5; Accessible.name: qsTr("Back to Control Center"); onClicked: root.backRequested() }
        IslandText { Layout.fillWidth: true; text: IslandTimer.pomodoro ? qsTr("Pomodoro") : qsTr("Timer"); font.pixelSize: 16; font.weight: Font.DemiBold }
        Row {
            visible: IslandTimer.pomodoro
            spacing: 5
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 8; height: 8; radius: 4
                    color: index < IslandTimer.completed % 4 || IslandTimer.completed > 0 && IslandTimer.completed % 4 === 0 && IslandTimer.phase === "longBreak" ? IslandTheme.palette.m3tertiary : IslandTheme.palette.chip
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 168
        Shape {
            id: ring
            anchors.centerIn: parent
            width: 160; height: 160
            preferredRendererType: Shape.CurveRenderer
            readonly property real stroke: 8
            ShapePath {
                strokeColor: IslandTheme.palette.chip; strokeWidth: ring.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 80; centerY: 80; radiusX: 80 - ring.stroke / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: IslandTimer.paused ? IslandTheme.palette.warning : IslandTimer.phase === "focus" || !IslandTimer.pomodoro ? IslandTheme.palette.m3tertiary : IslandTheme.palette.success
                strokeWidth: ring.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 80; centerY: 80; radiusX: 80 - ring.stroke / 2; radiusY: radiusX; startAngle: -90; sweepAngle: root.active ? 360 * (1 - IslandTimer.progress) : 0 }
            }
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            IslandText { Layout.alignment: Qt.AlignHCenter; text: root.active ? IslandTimer.clock : `${root.customMinutes.toString().padStart(2, "0")}:00`; font.pixelSize: 34; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
            IslandText { Layout.alignment: Qt.AlignHCenter; text: root.active ? IslandTimer.paused ? qsTr("Paused") : IslandTimer.label : qsTr("Set a timer"); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant }
        }
    }

    // Idle: presets and a custom stepper.
    GridLayout {
        Layout.fillWidth: true
        visible: !root.active
        columns: 4; rowSpacing: 8; columnSpacing: 8
        Repeater {
            model: [1, 5, 10, 15, 25, 30, 45, 60]
            IslandButton {
                required property int modelData
                Layout.fillWidth: true
                implicitHeight: 34
                text: modelData < 60 ? qsTr("%1 min").arg(modelData) : qsTr("1 hr")
                background: Rectangle { radius: height / 2; color: parent.hovered ? IslandTheme.palette.cardHover : IslandTheme.palette.card }
                onClicked: IslandTimer.start(modelData)
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !root.active
        spacing: 8
        IslandButton { iconName: "remove"; implicitWidth: 34; implicitHeight: 34; leftPadding: 7; rightPadding: 7; enabled: root.customMinutes > 1; autoRepeat: true; Accessible.name: qsTr("Less time"); onClicked: root.customMinutes = Math.max(1, root.customMinutes - (root.customMinutes > 10 ? 5 : 1)) }
        IslandButton { iconName: "add"; implicitWidth: 34; implicitHeight: 34; leftPadding: 7; rightPadding: 7; enabled: root.customMinutes < 180; autoRepeat: true; Accessible.name: qsTr("More time"); onClicked: root.customMinutes = Math.min(180, root.customMinutes + (root.customMinutes >= 10 ? 5 : 1)) }
        Item { Layout.fillWidth: true }
        IslandButton { iconName: "self_improvement"; text: qsTr("Pomodoro"); implicitHeight: 34; onClicked: IslandTimer.startPomodoro() }
        IslandButton { iconName: "play_arrow"; text: qsTr("Start"); accent: true; implicitHeight: 34; onClicked: IslandTimer.start(root.customMinutes) }
    }

    // Running: adjust, pause, stop.
    RowLayout {
        Layout.fillWidth: true
        visible: root.active
        spacing: 8
        IslandButton { text: qsTr("+1 min"); implicitHeight: 36; onClicked: IslandTimer.addMinutes(1) }
        IslandButton { text: qsTr("+5 min"); implicitHeight: 36; onClicked: IslandTimer.addMinutes(5) }
        Item { Layout.fillWidth: true }
        IslandButton { visible: IslandTimer.pomodoro; iconName: "skip_next"; implicitWidth: 36; implicitHeight: 36; leftPadding: 8; rightPadding: 8; Accessible.name: qsTr("Skip to next phase"); onClicked: IslandTimer.skip() }
        IslandButton { iconName: "stop"; implicitWidth: 36; implicitHeight: 36; leftPadding: 8; rightPadding: 8; Accessible.name: qsTr("Stop timer"); onClicked: IslandTimer.stop() }
        IslandButton { iconName: IslandTimer.paused ? "play_arrow" : "pause"; accent: true; implicitWidth: 44; implicitHeight: 36; Accessible.name: IslandTimer.paused ? qsTr("Resume") : qsTr("Pause"); onClicked: IslandTimer.toggle() }
    }
}
