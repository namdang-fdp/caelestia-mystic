// Compact text capsule inspired by Tide-island's NotificationLayer (GPL-3.0).
// Uses Caelestia's tracked notification object for actions, expiry and history.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root
    required property var notification
    property int waiting
    property bool detailed
    signal expansionRequested
    implicitHeight: detailed ? Math.min(260, body.implicitHeight + 112 + (actions.count ? 44 : 0)) : 76
    function clean(value: string): string { return value.replace(/<[^>]*>/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").trim(); }
    Component.onCompleted: notification.lock(root)
    Component.onDestruction: notification.unlock(root)
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.expansionRequested() }
    RowLayout {
        id: heading
        x: 16
        y: 12
        width: parent.width - 24
        spacing: 10
        Item {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            IconImage { anchors.fill: parent; visible: !!root.notification.appIcon; source: Quickshell.iconPath(root.notification.appIcon) }
            MaterialIcon { anchors.centerIn: parent; visible: !root.notification.appIcon; text: "notifications"; color: IslandTheme.palette.m3primary; fontStyle: Tokens.font.icon.medium }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            IslandText { Layout.fillWidth: true; text: `${root.notification.appName}${root.waiting ? " · +" + root.waiting : ""}`; color: IslandTheme.palette.m3onSurfaceVariant; islandFont: Tokens.font.label.small; elide: Text.ElideRight }
            IslandText { Layout.fillWidth: true; text: root.notification.summary; islandFont: Tokens.font.label.large; elide: Text.ElideRight }
        }
        IslandButton { iconName: root.detailed ? "unfold_less" : "unfold_more"; Accessible.name: qsTr("Expand notification"); onClicked: root.expansionRequested() }
        IslandButton { iconName: "close"; Accessible.name: qsTr("Dismiss popup"); onClicked: root.notification.popup = false }
    }
    IslandText {
        x: 56
        y: 51
        width: parent.width - 116
        visible: !root.detailed
        text: root.clean(root.notification.body)
        islandFont: Tokens.font.body.small
        color: IslandTheme.palette.m3onSurfaceVariant
        elide: Text.ElideRight
    }
    Flickable {
        x: 18
        y: 72
        width: parent.width - 36
        height: Math.max(0, parent.height - y - (actions.count ? 54 : 18))
        visible: root.detailed
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        IslandText { id: body; width: parent.width; text: root.clean(root.notification.body); wrapMode: Text.Wrap; color: IslandTheme.palette.m3onSurfaceVariant }
    }
    ListView {
        id: actions
        x: 18
        y: parent.height - 48
        width: parent.width - 36
        height: 36
        spacing: 8
        orientation: ListView.Horizontal
        clip: true
        visible: root.detailed
        model: root.notification.actions.filter(a => a.identifier !== "default")
        delegate: IslandButton {
            required property var modelData
            text: modelData.text
            accent: true
            onClicked: { modelData.invoke(); root.notification.popup = false; }
        }
    }
}
