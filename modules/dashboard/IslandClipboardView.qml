pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "helpers/ClipboardLogic.js" as Logic

FocusScope {
    id: root
    objectName: "islandClipboardView"
    signal closeRequested
    property bool copying
    property string filter: "all"
    property bool confirmClear
    readonly property var query: Logic.parseQuery(search.text)
    readonly property var entries: IslandClipboard.items.filter(e => (filter === "all" || (filter === "pinned" ? e.pinned : e.type === filter)) && Logic.matches(e, query))
    onEntriesChanged: list.currentIndex = Math.max(0, Math.min(list.currentIndex, entries.length - 1))
    implicitHeight: 372
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
            IslandTextField {
                id: search
                objectName: "islandClipboardSearch"
                Layout.fillWidth: true
                implicitHeight: 36
                placeholderText: qsTr("Search · @image @link @code @app")
                onTextChanged: list.currentIndex = 0
                Keys.onDownPressed: list.currentIndex = Math.min(root.entries.length - 1, list.currentIndex + 1)
                Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                onAccepted: root.copyCurrent()
            }
            IslandButton { iconName: "refresh"; enabled: !IslandClipboard.busy; Accessible.name: qsTr("Refresh clipboard"); onClicked: IslandClipboard.refresh() }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: [{id:"all",label:qsTr("All")},{id:"pinned",label:qsTr("Pinned")},{id:"text",label:qsTr("Text")},{id:"image",label:qsTr("Images")},{id:"link",label:qsTr("Links")},{id:"code",label:qsTr("Code")}]
                IslandButton {
                    required property var modelData
                    objectName: "islandClipboardFilter_" + modelData.id
                    Layout.fillWidth: true
                    text: modelData.label
                    checked: root.filter === modelData.id
                    implicitHeight: 28
                    leftPadding: 6; rightPadding: 6
                    onClicked: { root.filter = modelData.id; list.currentIndex = 0; search.forceActiveFocus(); }
                }
            }
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
                objectName: "islandClipboardEntry_" + modelData.id
                required property var modelData
                required property int index
                readonly property string thumb: modelData.image ? IslandClipboard.thumbs[modelData.id] ?? "" : ""
                width: list.width
                height: modelData.image ? 76 : 54
                Component.onCompleted: if (modelData.image) IslandClipboard.requestThumb(modelData.id)
                radius: 14
                color: list.currentIndex === index ? IslandTheme.palette.m3surfaceContainerHighest : IslandTheme.palette.m3surfaceContainerHigh
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { list.currentIndex = entryRow.index; root.copyCurrent(); } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 6
                    spacing: 12
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
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        IslandText {
                            Layout.fillWidth: true
                            text: root.describe(entryRow.modelData)
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            islandFont: Tokens.font.body.small
                        }
                        IslandText { visible: !!entryRow.modelData.app; Layout.fillWidth: true; text: "@" + entryRow.modelData.app; font.pixelSize: 10; color: IslandTheme.palette.m3outline; elide: Text.ElideRight }
                    }
                    IslandButton {
                        objectName: "islandClipboardPin_" + entryRow.modelData.id
                        iconName: entryRow.modelData.pinned ? "keep_off" : "keep"
                        checked: entryRow.modelData.pinned
                        implicitWidth: 30; implicitHeight: 30
                        leftPadding: 4; rightPadding: 4
                        enabled: !IslandClipboard.busy
                        Accessible.name: entryRow.modelData.pinned ? qsTr("Unpin this item") : qsTr("Pin this item")
                        onClicked: IslandClipboard.act(entryRow.modelData.pinned ? "unpin" : "pin", entryRow.modelData.id)
                    }
                    IslandButton {
                        visible: !entryRow.modelData.pinned
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
                text: IslandClipboard.error || (IslandClipboard.busy ? qsTr("Loading…") : search.text || root.filter !== "all" ? qsTr("No matching items") : qsTr("Your copied text and images appear here"))
                color: IslandClipboard.error ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurfaceVariant
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: IslandClipboard.stackMode && IslandClipboard.stack.length > 0
            spacing: 8
            MaterialIcon { text: "layers"; color: IslandTheme.palette.orange; fontStyle: Tokens.font.icon.small }
            IslandText { Layout.fillWidth: true; text: qsTr("Stack · %1 waiting, pasted in order").arg(IslandClipboard.stack.length); font.pixelSize: 12 }
            IslandButton { text: qsTr("Copy next"); accent: true; accentColour: IslandTheme.palette.orange; implicitHeight: 28; enabled: !IslandClipboard.busy; onClicked: IslandClipboard.nextFromStack() }
            IslandButton { text: qsTr("Clear"); implicitHeight: 28; onClicked: IslandClipboard.clearStack() }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            IslandButton { iconName: IslandClipboard.paused ? "play_arrow" : "pause"; text: IslandClipboard.paused ? qsTr("Paused") : qsTr("Pause"); checked: IslandClipboard.paused; implicitHeight: 26; leftPadding: 8; rightPadding: 8; Accessible.name: IslandClipboard.paused ? qsTr("Resume recording clipboard") : qsTr("Pause clipboard recording"); onClicked: IslandClipboard.setPaused(!IslandClipboard.paused) }
            IslandButton { iconName: "layers"; text: qsTr("Stack"); checked: IslandClipboard.stackMode; implicitHeight: 26; leftPadding: 8; rightPadding: 8; Accessible.name: qsTr("Copy Stack"); onClicked: IslandClipboard.setStackMode(!IslandClipboard.stackMode) }
            IslandButton { iconName: "auto_delete"; text: Logic.retentionLabel(IslandClipboard.retentionHours); checked: IslandClipboard.retentionHours > 0; implicitHeight: 26; leftPadding: 8; rightPadding: 8; Accessible.name: qsTr("Auto-delete after: %1").arg(text); onClicked: IslandClipboard.cycleRetention() }
            IslandButton {
                iconName: "delete_sweep"
                text: root.confirmClear ? qsTr("Sure? Clear all") : qsTr("Clear all")
                checked: root.confirmClear
                implicitHeight: 26; leftPadding: 8; rightPadding: 8
                enabled: !IslandClipboard.busy
                Accessible.name: root.confirmClear ? qsTr("Confirm: delete all recent clipboard items") : qsTr("Delete all recent clipboard items")
                onClicked: {
                    if (root.confirmClear) { root.confirmClear = false; IslandClipboard.wipe(); }
                    else { root.confirmClear = true; confirmReset.restart(); }
                }
            }
            Timer { id: confirmReset; interval: 3000; onTriggered: root.confirmClear = false }
            Item { Layout.fillWidth: true }
            IslandText { text: IslandClipboard.paused ? qsTr("New copies are not kept") : qsTr("%1 items").arg(root.entries.length); islandFont: Tokens.font.label.small; color: IslandClipboard.paused ? IslandTheme.palette.orange : IslandTheme.palette.m3onSurfaceVariant }
        }
    }
}
