pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.sidebar as History

Item {
    id: root
    required property ScreenState screenState
    implicitHeight: 360
    History.Props { id: historyProps; textFamily: Tokens.font.body.small.family }
    RowLayout {
        id: heading
        width: parent.width
        IslandText { Layout.fillWidth: true; text: qsTr("Notification history"); islandFont: Tokens.font.label.large }
        IslandButton { iconName: "notifications_off"; text: qsTr("DND"); checked: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
    }
    Item {
        anchors.top: heading.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        History.NotifDock { props: historyProps; screenState: root.screenState }
    }
}
