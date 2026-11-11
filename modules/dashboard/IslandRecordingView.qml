pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import "helpers/ActivityLogic.js" as Logic

ColumnLayout {
    spacing: 14
    RowLayout {
        spacing: 10
        Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: Recorder.running ? IslandTheme.palette.m3error : IslandTheme.palette.m3outline }
        IslandText {
            Layout.fillWidth: true
            text: !Recorder.running ? qsTr("No recording in progress") : Recorder.paused ? qsTr("Paused") : qsTr("Recording")
            font.pixelSize: 14
        }
        IslandText { visible: Recorder.running; text: Logic.clock(Recorder.elapsed); font.pixelSize: 20; font.features: { "tnum": 1 } }
    }
    IslandText {
        Layout.fillWidth: true
        text: qsTr("Stop to save your recording. More recording options are available in Utilities.")
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        color: IslandTheme.palette.m3onSurfaceVariant
    }
    RowLayout {
        Layout.fillWidth: true
        visible: Recorder.running
        IslandButton {
            Layout.fillWidth: true
            text: Recorder.paused ? qsTr("Resume") : qsTr("Pause")
            iconName: Recorder.paused ? "play_arrow" : "pause"
            enabled: !Recorder.busy
            onClicked: Recorder.togglePause()
        }
        IslandButton {
            Layout.fillWidth: true
            text: qsTr("Stop and save")
            iconName: "stop"
            accent: true
            enabled: !Recorder.busy
            onClicked: Recorder.stop()
        }
    }
}
