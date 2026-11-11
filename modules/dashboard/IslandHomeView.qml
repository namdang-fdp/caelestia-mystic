pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import "helpers/AgentLogic.js" as AgentLogic

// Home: a small bento of widgets. Each tile is one glanceable thing, tinted
// with its own colour; tapping a tile opens its page.
ColumnLayout {
    id: root
    objectName: "islandHomeView"
    signal pageRequested(string page)
    property bool editing
    property real maximumHeight: 480
    readonly property var player: IslandAudio.player ?? (IslandAudio.audible ? null : Players.active)
    readonly property var devices: (Bluetooth.defaultAdapter?.devices.values ?? []).filter(d => d?.connected && d.batteryAvailable)
    readonly property var modules: IslandHome.visibleModules(IslandShelf.count > 0, Config.dashboard.showMedia, AgentState.hasSessions || AgentState.hasStats)
    readonly property string art: Players.getArtUrl(player)
    readonly property real battery: UPower.displayDevice.percentage
    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery
    readonly property color batteryColour: !hasBattery || charging || battery > .2 ? IslandTheme.palette.green : battery > .1 ? IslandTheme.palette.orange : IslandTheme.palette.red
    spacing: 14
    readonly property string greeting: { const h = Time.date.getHours(); return h < 5 ? qsTr("Good night") : h < 12 ? qsTr("Good morning") : h < 18 ? qsTr("Good afternoon") : qsTr("Good evening"); }
    function moduleName(id: string): string { return ({media:qsTr("Music"),timer:qsTr("Timer"),battery:qsTr("Battery & devices"),notes:qsTr("Today"),agent:qsTr("Agent"),shelf:qsTr("File shelf")})[id] ?? id; }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            IslandText { Layout.fillWidth: true; text: root.editing ? qsTr("Customize Home") : root.greeting; font.pixelSize: 22; font.weight: Font.DemiBold; elide: Text.ElideRight }
            IslandText { Layout.fillWidth: true; text: Time.format("dddd, MMMM d"); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight }
        }
        IslandButton {
            objectName: "islandHomeCustomize"
            text: root.editing ? qsTr("Done") : ""
            iconName: root.editing ? "check" : "tune"
            accent: root.editing
            implicitHeight: 32
            implicitWidth: root.editing ? implicitWidth : 36
            leftPadding: root.editing ? 12 : 8; rightPadding: root.editing ? 12 : 8
            Accessible.name: root.editing ? qsTr("Done customizing") : qsTr("Customize Home")
            onClicked: root.editing = !root.editing
        }
    }

    Flickable {
        id: scroll
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Math.max(contentHeight, 120), Math.max(120, root.maximumHeight - 50))
        contentHeight: root.editing ? editor.implicitHeight : widgets.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: editor
            width: scroll.width
            visible: root.editing
            spacing: 6
            IslandText { Layout.fillWidth: true; text: qsTr("Drag to reorder, or switch widgets off."); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant; wrapMode: Text.WordWrap }
            Repeater {
                model: IslandHome.order
                RowLayout {
                    id: editRow
                    required property string modelData
                    required property int index
                    property real dragY
                    readonly property real step: height + editor.spacing
                    Layout.fillWidth: true
                    spacing: 8
                    z: handleArea.pressed ? 2 : 0
                    transform: Translate { y: editRow.dragY }
                    Rectangle {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 30; radius: 8
                        color: handleArea.pressed ? IslandTheme.palette.m3surfaceContainerHighest : "transparent"
                        Accessible.name: qsTr("Drag to reorder %1").arg(root.moduleName(editRow.modelData))
                        MaterialIcon { anchors.centerIn: parent; text: "drag_indicator"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.small }
                        MouseArea {
                            id: handleArea
                            anchors.fill: parent
                            enabled: IslandHome.loaded
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property real startY
                            onPressed: mouse => { startY = mapToItem(editor, mouse.x, mouse.y).y; }
                            onPositionChanged: mouse => { if (pressed) editRow.dragY = mapToItem(editor, mouse.x, mouse.y).y - startY; }
                            onReleased: {
                                const target = editRow.index + Math.round(editRow.dragY / editRow.step);
                                editRow.dragY = 0;
                                IslandHome.moveTo(editRow.modelData, target);
                            }
                            onCanceled: editRow.dragY = 0
                        }
                    }
                    IslandText { Layout.fillWidth: true; text: root.moduleName(editRow.modelData); font.pixelSize: 13 }
                    IslandButton { objectName: "islandHomeUp_" + editRow.modelData; iconName: "arrow_upward"; implicitWidth: 30; implicitHeight: 30; leftPadding: 4; rightPadding: 4; enabled: editRow.index > 0 && IslandHome.loaded; Accessible.name: qsTr("Move %1 up").arg(root.moduleName(editRow.modelData)); onClicked: IslandHome.move(editRow.modelData,-1) }
                    IslandButton { objectName: "islandHomeDown_" + editRow.modelData; iconName: "arrow_downward"; implicitWidth: 30; implicitHeight: 30; leftPadding: 4; rightPadding: 4; enabled: editRow.index < IslandHome.order.length-1 && IslandHome.loaded; Accessible.name: qsTr("Move %1 down").arg(root.moduleName(editRow.modelData)); onClicked: IslandHome.move(editRow.modelData,1) }
                    IslandSwitch { objectName: "islandHomeToggle_" + editRow.modelData; checked: !IslandHome.disabled.includes(editRow.modelData); enabled: IslandHome.loaded; Accessible.name: qsTr("Show %1").arg(root.moduleName(editRow.modelData)); onClicked: IslandHome.toggle(editRow.modelData) }
                }
            }
        }

        GridLayout {
            id: widgets
            width: scroll.width
            visible: !root.editing
            columns: width >= 460 ? 3 : 2
            uniformCellWidths: true
            rowSpacing: 12; columnSpacing: 12
            Repeater {
                model: root.modules
                Loader {
                    required property string modelData
                    objectName: "islandHomeWidget_" + modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: modelData === "shelf" ? 92 : 160
                    Layout.columnSpan: modelData === "media" ? Math.min(2, widgets.columns) : modelData === "shelf" ? widgets.columns : 1
                    sourceComponent: ({media:musicTile,timer:timerTile,agent:agentTile,battery:batteryTile,notes:todayTile,shelf:shelfTile})[modelData]
                }
            }
            IslandText { visible: !root.modules.length; Layout.columnSpan: widgets.columns; Layout.fillWidth: true; text: qsTr("Your overview is empty. Choose Customize to add a widget."); font.pixelSize: 13; wrapMode: Text.WordWrap; color: IslandTheme.palette.m3onSurfaceVariant }
        }
    }

    // A tile: tinted wash, small caption, whole tile opens its page.
    component Tile: ClippingRectangle {
        id: tile
        required property string page
        required property string caption
        property color tint: IslandTheme.palette.blue
        default property alias contents: body.data
        anchors.fill: parent
        radius: 26
        color: hover.hovered ? IslandTheme.palette.cardHover : IslandTheme.palette.card
        clip: true
        Behavior on color { ColorAnimation { duration: 140 * Tokens.anim.durations.scale } }
        Rectangle {
            anchors.fill: parent
            radius: tile.radius
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Qt.alpha(tile.tint, .22) }
                GradientStop { position: .7; color: "transparent" }
            }
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.pageRequested(tile.page) }
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Open %1").arg(tile.caption)
        IslandText { x: 16; y: 14; text: tile.caption.toUpperCase(); font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: .8; color: tile.tint }
        Item { id: body; x: 16; y: 36; width: parent.width - 32; height: parent.height - 50 }
    }

    // Ring with a centre label, shared by Timer and Battery.
    component Gauge: Item {
        id: gauge
        property real progress
        property color colour: IslandTheme.palette.green
        property real size: 84
        default property alias centre: inner.data
        implicitWidth: size; implicitHeight: size
        IslandRing { anchors.fill: parent; progress: gauge.progress; colour: gauge.colour }
        Item { id: inner; anchors.fill: parent }
    }

    Component {
        id: musicTile
        Tile {
            caption: qsTr("Music"); page: "media"; tint: IslandTheme.palette.pink
            Image { x: -16; y: -36; width: parent.parent.width; height: parent.parent.height; source: root.art; sourceSize: Qt.size(200, 200); fillMode: Image.PreserveAspectCrop; opacity: .16; visible: !!root.art; asynchronous: true }
            RowLayout {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                spacing: 12
                ClippingRectangle {
                    Layout.preferredWidth: 60; Layout.preferredHeight: 60; radius: 14; color: IslandTheme.palette.chip
                    Image { anchors.fill: parent; source: root.art; sourceSize: Qt.size(120, 120); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    MaterialIcon { anchors.centerIn: parent; visible: !root.art; text: "music_note"; color: IslandTheme.palette.m3outline; fontStyle: Tokens.font.icon.medium }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    IslandText { Layout.fillWidth: true; text: root.player?.trackTitle || (IslandAudio.audible ? IslandAudio.label : qsTr("Nothing playing")); font.pixelSize: 15; font.weight: Font.Bold; elide: Text.ElideRight }
                    IslandText { Layout.fillWidth: true; text: root.player?.trackArtist || (root.player ? Players.getIdentity(root.player) : qsTr("Open your music player")); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight }
                }
            }
            RowLayout {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                spacing: 14
                IslandButton { iconName: "skip_previous"; implicitHeight: 34; implicitWidth: 38; leftPadding: 8; rightPadding: 8; enabled: !!root.player?.canGoPrevious; Accessible.name: qsTr("Previous track"); onClicked: root.player?.previous() }
                IslandButton { iconName: root.player?.isPlaying ? "pause" : "play_arrow"; accent: true; accentColour: "#ffffff"; accentText: "#000000"; implicitHeight: 38; implicitWidth: 38; leftPadding: 7; rightPadding: 7; enabled: !!root.player?.canTogglePlaying; Accessible.name: root.player?.isPlaying ? qsTr("Pause") : qsTr("Play"); onClicked: root.player?.togglePlaying() }
                IslandButton { iconName: "skip_next"; implicitHeight: 34; implicitWidth: 38; leftPadding: 8; rightPadding: 8; enabled: !!root.player?.canGoNext; Accessible.name: qsTr("Next track"); onClicked: root.player?.next() }
            }
        }
    }

    Component {
        id: timerTile
        Tile {
            caption: qsTr("Timer"); page: "timer"; tint: IslandTheme.palette.orange
            Gauge {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                size: 86
                progress: IslandTimer.active ? 1 - IslandTimer.progress : 0
                colour: IslandTimer.paused ? IslandTheme.palette.yellow : IslandTheme.palette.orange
                IslandText { anchors.centerIn: parent; anchors.verticalCenterOffset: -6; text: IslandTimer.active ? IslandTimer.clock : "25:00"; font.pixelSize: 19; font.weight: Font.DemiBold; font.features: {"tnum":1}; color: IslandTimer.active ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3onSurfaceVariant }
                IslandButton {
                    objectName: "islandHomeTimerAction"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                    iconName: IslandTimer.active && !IslandTimer.paused ? "pause" : "play_arrow"
                    implicitHeight: 24; implicitWidth: 28; leftPadding: 4; rightPadding: 4
                    Accessible.name: IslandTimer.active ? IslandTimer.paused ? qsTr("Resume") : qsTr("Pause") : qsTr("Start 25 min")
                    onClicked: IslandTimer.active ? IslandTimer.toggle() : IslandTimer.start(25)
                }
            }
        }
    }

    Component {
        id: batteryTile
        Tile {
            caption: root.charging ? qsTr("Charging") : UPower.onBattery && root.hasBattery ? qsTr("Battery") : qsTr("Plugged in")
            page: "info"; tint: root.batteryColour
            Gauge {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                size: 86
                progress: root.hasBattery ? root.battery : 1
                colour: root.batteryColour
                IslandText { anchors.centerIn: parent; anchors.verticalCenterOffset: root.charging ? -5 : 0; text: root.hasBattery ? `${Math.round(root.battery * 100)}` : "AC"; font.pixelSize: 26; font.weight: Font.DemiBold; font.features: {"tnum":1} }
                MaterialIcon { visible: root.charging; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: "bolt"; fill: 1; color: root.batteryColour; fontStyle: Tokens.font.icon.small }
            }
        }
    }

    Component {
        id: agentTile
        Tile {
            id: agent
            caption: qsTr("Agent"); page: "agent"
            tint: AgentState.foreground === "waiting" ? IslandTheme.palette.orange : AgentState.foreground === "working" ? IslandTheme.palette.green : IslandTheme.palette.purple
            RowLayout {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                spacing: 8
                IslandAgentMark { state: AgentState.foreground || "done"; size: 18; visible: !!AgentState.foreground }
                IslandText { Layout.fillWidth: true; text: AgentState.foreground === "waiting" ? qsTr("Needs you") : AgentState.foreground === "working" ? qsTr("Working") : qsTr("Idle"); font.pixelSize: 17; font.weight: Font.DemiBold; elide: Text.ElideRight }
            }
            IslandText { anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 28 } text: AgentState.primary ? `${AgentState.primary.project || AgentLogic.agentName(AgentState.primary.agent)}` : qsTr("No sessions"); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight }
            ColumnLayout {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                spacing: 0
                IslandText { text: AgentLogic.compact((AgentState.provider("claude")?.today?.tokens ?? 0) + (AgentState.provider("codex")?.today?.tokens ?? 0)); font.pixelSize: 26; font.weight: Font.DemiBold; font.features: {"tnum":1} }
                IslandText { text: qsTr("tokens today"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
            }
        }
    }

    Component {
        id: todayTile
        Tile {
            caption: Time.format("ddd"); page: "info"; tint: IslandTheme.palette.red
            IslandText { id: dayNumber; anchors { left: parent.left; top: parent.top; topMargin: -4 } text: Time.format("d"); font.pixelSize: 46; font.weight: Font.DemiBold; font.features: {"tnum":1} }
            IslandText {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                text: CalendarNotes.noteFor(Time.date) || qsTr("No note today")
                font.pixelSize: 12; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight
                color: CalendarNotes.hasNote(Time.date) ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3onSurfaceVariant
            }
        }
    }

    Component {
        id: shelfTile
        Tile {
            caption: qsTr("Shelf · %1").arg(IslandShelf.count); page: "shelf"; tint: IslandTheme.palette.blue
            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8
                Repeater {
                    model: IslandShelf.items.slice(0, 3)
                    IslandButton {
                        required property var modelData
                        width: Math.min(implicitWidth, 150)
                        text: modelData.name; implicitHeight: 28
                        Accessible.name: qsTr("Open %1").arg(modelData.name)
                        onClicked: IslandShelf.open(modelData.path)
                        contentItem: IslandText { text: parent.text; font.pixelSize: 12; elide: Text.ElideMiddle }
                        background: Rectangle { radius: 14; color: IslandTheme.palette.chip }
                    }
                }
            }
        }
    }
}
