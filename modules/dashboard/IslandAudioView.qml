pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "helpers/ActivityLogic.js" as Logic

ColumnLayout {
    id: root
    property var pendingNode: null
    property bool input
    property bool pendingInput
    property string error
    spacing: 10

    function selectDevice(node: var, input: bool): void {
        if (!node?.ready || pendingNode) return;
        error = "";
        pendingInput = input;
        pendingNode = node;
        switchTimeout.restart();
        if (input) Audio.setAudioSource(node);
        else Audio.setAudioSink(node);
        confirmSelection();
    }
    function confirmSelection(): void {
        if (pendingNode && pendingNode === (pendingInput ? Audio.source : Audio.sink)) {
            pendingNode = null;
            switchTimeout.stop();
        }
    }
    Connections {
        target: Audio
        function onSinkChanged(): void { root.confirmSelection(); }
        function onSourceChanged(): void { root.confirmSelection(); }
    }
    Timer {
        id: switchTimeout
        interval: 2500
        onTriggered: {
            root.pendingNode = null;
            root.error = qsTr("Could not switch audio device. Check its connection and try again.");
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        IslandButton {
            objectName: "islandAudioOutputTab"
            Layout.fillWidth: true
            text: qsTr("Output"); iconName: "volume_up"
            checked: !root.input
            onClicked: root.input = false
        }
        IslandButton {
            objectName: "islandAudioInputTab"
            Layout.fillWidth: true
            text: qsTr("Input"); iconName: "mic"
            checked: root.input
            onClicked: root.input = true
        }
    }
    Flickable {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 320)
        contentHeight: sections.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        function reveal(item: Item): void {
            const top = item.mapToItem(sections, 0, 0).y;
            if (top < contentY) contentY = top;
            else if (top + item.height > contentY + height) contentY = top + item.height - height;
        }
        ColumnLayout {
            id: sections
            width: list.width
            spacing: 4
            Repeater {
                model: root.input ? Audio.sources : Audio.sinks
                DeviceRow { required property var modelData; node: modelData; input: root.input }
            }
            EmptyLabel {
                visible: !(root.input ? Audio.sources.length : Audio.sinks.length)
                text: root.input ? qsTr("No input devices available") : qsTr("No output devices available")
            }
        }
    }
    IslandText {
        Layout.fillWidth: true
        visible: !!root.error
        text: root.error
        color: IslandTheme.palette.m3error
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
    component EmptyLabel: IslandText {
        Layout.fillWidth: true
        Layout.margins: 8
        font.pixelSize: 12
        color: IslandTheme.palette.m3outline
        wrapMode: Text.WordWrap
    }
    component DeviceRow: IslandListRow {
        id: device
        required property var node
        property bool input
        objectName: "islandAudioDevice_" + (input ? "input_" : "output_") + (node?.id ?? "removed")
        Layout.fillWidth: true
        // PipeWire can destroy a node before its list model drops the delegate.
        readonly property string deviceDescription: node?.description || node?.name || qsTr("Disconnected device")
        text: node?.nickname || deviceDescription
        active: !!node && node === (input ? Audio.source : Audio.sink)
        enabled: !!node?.ready && (!root.pendingNode || root.pendingNode === node)
        busy: !!node && root.pendingNode === node
        iconName: input ? "mic" : Logic.bluetoothIcon(node?.properties["device.icon_name"] || "audio-card")
        readonly property string status: !node?.ready ? qsTr("Unavailable") : busy ? qsTr("Switching…") : active ? qsTr("Selected") : qsTr("Use this device")
        subtitle: deviceDescription !== text ? `${status} · ${deviceDescription}` : status
        Accessible.name: `${deviceDescription}, ${status}`
        ToolTip.visible: hovered && !!node
        ToolTip.text: deviceDescription
        ToolTip.delay: 600
        onClicked: root.selectDevice(node, input)
        onActiveFocusChanged: if (activeFocus) list.reveal(this)
        MaterialIcon { visible: device.active; text: "check"; fontStyle: Tokens.font.icon.small; color: IslandTheme.palette.m3tertiary }
    }
}
