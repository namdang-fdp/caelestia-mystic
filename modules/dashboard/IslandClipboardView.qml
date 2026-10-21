pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

FocusScope {
    id: root
    signal closeRequested
    property bool copying
    readonly property var entries: IslandClipboard.entries.filter(e => e.label.toLowerCase().includes(search.text.toLowerCase()))
    implicitHeight: 304
    function copyCurrent(): void {
        const entry = entries[list.currentIndex];
        if (entry && !IslandClipboard.busy) { copying = true; IslandClipboard.act("copy", entry.id); }
    }
    Component.onCompleted: { IslandClipboard.viewers++; IslandClipboard.refresh(); search.forceActiveFocus(); }
    Component.onDestruction: IslandClipboard.viewers--
    Connections { target: IslandClipboard; function onCopied(): void { if (root.copying) root.closeRequested(); } }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            StyledTextField {
                id: search
                font.family: IslandTheme.fontFamily
                Layout.fillWidth: true
                placeholderText: qsTr("Search clipboard…")
                leadingIcon: "search"
                radius: 18
                onTextChanged: list.currentIndex = 0
                Keys.onDownPressed: list.currentIndex = Math.min(root.entries.length - 1, list.currentIndex + 1)
                Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                onAccepted: root.copyCurrent()
            }
            IslandButton { iconName: "refresh"; enabled: !IslandClipboard.busy; Accessible.name: qsTr("Refresh clipboard"); onClicked: IslandClipboard.refresh() }
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.entries
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: entryRow
                required property var modelData
                required property int index
                width: list.width
                height: 54
                radius: 14
                color: list.currentIndex === index ? IslandTheme.palette.m3surfaceContainerHighest : IslandTheme.palette.m3surfaceContainerHigh
                border.width: list.currentIndex === index ? 1 : 0
                border.color: Qt.alpha(IslandTheme.palette.m3primary, 0.4)
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { list.currentIndex = entryRow.index; root.copyCurrent(); } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 6
                    spacing: 12
                    MaterialIcon { text: entryRow.modelData.image ? "image" : "content_copy"; color: IslandTheme.palette.m3primary; fontStyle: Tokens.font.icon.medium }
                    IslandText {
                        Layout.fillWidth: true
                        text: entryRow.modelData.label
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        islandFont: Tokens.font.body.small
                    }
                    IslandButton {
                        iconName: "close"
                        enabled: !IslandClipboard.busy
                        Accessible.name: qsTr("Delete this clipboard entry")
                        onClicked: IslandClipboard.act("delete", entryRow.modelData.id)
                    }
                }
            }
            IslandText {
                anchors.centerIn: parent
                width: parent.width - 30
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: !!IslandClipboard.error || root.entries.length === 0
                text: IslandClipboard.error || (IslandClipboard.busy ? qsTr("Loading…") : search.text ? qsTr("No matching items") : qsTr("Your copied text and images appear here"))
                color: IslandClipboard.error ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurfaceVariant
            }
        }
        IslandText { text: qsTr("%1 items · ↑↓ to select · Enter to copy").arg(root.entries.length); islandFont: Tokens.font.label.small; color: IslandTheme.palette.m3outline }
    }
}
