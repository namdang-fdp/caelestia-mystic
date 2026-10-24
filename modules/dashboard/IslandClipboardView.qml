pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
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
    // cliphist describes images as "[[ binary data 302 KiB png 1166x770 ]]".
    function describe(entry: var): string {
        const match = entry.image ? /binary data\s+(.+?)\s+(\w+)\s+(\d+)x(\d+)/i.exec(entry.label) : null;
        return match ? qsTr("%1 image · %2×%3 · %4").arg(match[2].toUpperCase()).arg(match[3]).arg(match[4]).arg(match[1]) : entry.label;
    }
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
                readonly property string thumb: modelData.image ? IslandClipboard.thumbs[modelData.id] ?? "" : ""
                width: list.width
                height: modelData.image ? 76 : 54
                Component.onCompleted: if (modelData.image) IslandClipboard.requestThumb(modelData.id)
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
                    MaterialIcon { visible: !entryRow.modelData.image; text: "content_copy"; color: IslandTheme.palette.m3primary; fontStyle: Tokens.font.icon.medium }
                    ClippingRectangle {
                        visible: entryRow.modelData.image
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 60
                        radius: 10
                        color: IslandTheme.palette.m3surfaceContainerLow
                        MaterialIcon { anchors.centerIn: parent; visible: thumbnail.status !== Image.Ready; text: "image"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.medium }
                        Image {
                            id: thumbnail
                            anchors.fill: parent
                            source: entryRow.thumb ? "file://" + entryRow.thumb.split("/").map(encodeURIComponent).join("/") : ""
                            sourceSize: Qt.size(192, 120)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 160 * Tokens.anim.durations.scale } }
                        }
                    }
                    IslandText {
                        Layout.fillWidth: true
                        text: root.describe(entryRow.modelData)
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
