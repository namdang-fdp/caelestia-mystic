import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Static status glyph for an agent session: a blue dot while it works, an
// amber one when it needs you, a check once it is done. Nothing animates, so
// the island never repaints on its own while an agent runs.
Item {
    id: root
    property string state: "working"
    property real size: 18
    implicitWidth: size
    implicitHeight: size
    Accessible.role: Accessible.Indicator
    Accessible.name: ({ working: qsTr("Working"), waiting: qsTr("Needs your approval"), done: qsTr("Done") })[state] ?? ""

    Rectangle {
        visible: root.state !== "done"
        anchors.centerIn: parent
        width: root.size * .95; height: width; radius: width / 2
        color: root.state === "waiting" ? IslandTheme.palette.warning : IslandTheme.palette.success
        opacity: .22
    }
    Rectangle {
        visible: root.state !== "done"
        anchors.centerIn: parent
        width: root.size * .5; height: width; radius: width / 2
        color: root.state === "waiting" ? IslandTheme.palette.warning : IslandTheme.palette.success
    }
    MaterialIcon {
        visible: root.state === "done"
        anchors.centerIn: parent
        text: "check_circle"
        color: IslandTheme.palette.success
        fontStyle: Tokens.font.icon.small
    }
}
