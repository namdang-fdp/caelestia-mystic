pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.Services
import qs.services

Item {
    id: root
    property bool running
    implicitWidth: 34
    implicitHeight: 24
    // Release the shared provider while paused, muted or hidden.
    ServiceRef { service: root.running ? Audio.cava : null }
    Row {
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: 6
            Rectangle {
                required property int index
                readonly property real amplitude: root.running ? Math.max(0, Math.min(1, Audio.cava.values[Math.floor(index * Audio.cava.values.length / 6)] ?? 0)) : 0
                width: 4
                height: 3 + amplitude * 21
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: IslandTheme.palette.m3primary
                Behavior on height { NumberAnimation { duration: 75 * Tokens.anim.durations.scale; easing.type: Easing.OutQuad } }
            }
        }
    }
}
