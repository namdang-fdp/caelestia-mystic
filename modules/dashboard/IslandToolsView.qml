pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Templates as T
import Caelestia.Config
import qs.components
import qs.services
import "helpers/ToolsLogic.js" as Logic

// Everyday tools in one page: notes, todos, world clocks, breathing and focus.
ColumnLayout {
    id: root
    objectName: "islandToolsView"
    readonly property string tab: IslandTools.tab
    readonly property var tabs: [
        { id: "notes", icon: "sticky_note_2", title: qsTr("Notes"), tint: IslandTheme.palette.orange },
        { id: "todo", icon: "checklist", title: qsTr("To-do"), tint: IslandTheme.palette.blue },
        { id: "clocks", icon: "public", title: qsTr("Clocks"), tint: IslandTheme.palette.teal },
        { id: "breathe", icon: "air", title: qsTr("Breathe"), tint: IslandTheme.palette.green },
        { id: "focus", icon: "do_not_disturb_on", title: qsTr("Focus"), tint: IslandTheme.palette.purple }
    ]
    readonly property bool typing: notesArea.activeFocus || todoField.activeFocus
    spacing: 12
    Component.onCompleted: { IslandTools.clockViewers++; if (root.tab === "notes") focusDelay2.start(); }
    Timer { id: focusDelay2; interval: 260; onTriggered: notesArea.forceActiveFocus() }
    Component.onDestruction: IslandTools.clockViewers--

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: root.tabs
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool selected: modelData.id === root.tab
                Layout.fillWidth: selected
                implicitWidth: selected ? label.implicitWidth + 40 : 34
                implicitHeight: 34
                radius: 17
                color: selected ? modelData.tint : tap.containsMouse ? IslandTheme.palette.cardHover : IslandTheme.palette.chip
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.title
                Accessible.selected: selected
                Behavior on color { ColorAnimation { duration: 140 * Tokens.anim.durations.scale } }
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon { text: chip.modelData.icon; color: chip.selected ? "#ffffff" : IslandTheme.palette.m3onSurfaceVariant; fontStyle: Tokens.font.icon.small }
                    IslandText { id: label; visible: chip.selected; text: chip.modelData.title; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#ffffff" }
                }
                MouseArea { id: tap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: IslandTools.openTab(chip.modelData.id) }
            }
        }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 260
        currentIndex: root.tabs.findIndex(t => t.id === root.tab)

        // Notes
        Rectangle {
            radius: 18
            color: IslandTheme.palette.card
            border.width: notesArea.activeFocus ? 1.5 : 0
            border.color: Qt.alpha(IslandTheme.palette.orange, .8)
            Flickable {
                id: notesFlick
                anchors.fill: parent; anchors.margins: 2
                clip: true
                contentWidth: width
                contentHeight: notesArea.height
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                T.TextArea {
                    id: notesArea
                    objectName: "islandNotesArea"
                    width: notesFlick.width
                    height: Math.max(implicitHeight, notesFlick.height)
                    padding: 14
                    wrapMode: TextEdit.Wrap
                    color: IslandTheme.palette.m3onSurface
                    selectionColor: IslandTheme.palette.accent
                    font.family: IslandTheme.fontFamily
                    font.pixelSize: 14
                    focus: true
                    activeFocusOnPress: true
                    text: IslandTools.notes
                    onTextChanged: if (activeFocus) IslandTools.setNotes(text)
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < notesFlick.contentY) notesFlick.contentY = cursorRectangle.y;
                        else if (cursorRectangle.y + cursorRectangle.height > notesFlick.contentY + notesFlick.height) notesFlick.contentY = cursorRectangle.y + cursorRectangle.height - notesFlick.height;
                    }
                    Accessible.name: qsTr("Notes")
                    IslandText { visible: !notesArea.text && !notesArea.activeFocus; x: 14; y: 14; text: qsTr("Jot something down. It saves as you type."); font.pixelSize: 14; color: IslandTheme.palette.m3outline }
                }
            }
            Connections {
                target: IslandTools
                function onFocusNotes(): void { focusDelay.restart(); }
            }
            Timer { id: focusDelay; interval: 220; onTriggered: notesArea.forceActiveFocus() }
        }

        // To-do
        ColumnLayout {
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                IslandTextField {
                    id: todoField
                    objectName: "islandTodoField"
                    Layout.fillWidth: true
                    placeholderText: qsTr("Add a task")
                    Accessible.name: qsTr("New task")
                    onAccepted: { IslandTools.addTodo(text); text = ""; }
                }
                IslandButton { iconName: "add"; accent: true; implicitHeight: 38; implicitWidth: 38; leftPadding: 7; rightPadding: 7; enabled: todoField.text.trim().length > 0; Accessible.name: qsTr("Add task"); onClicked: { IslandTools.addTodo(todoField.text); todoField.text = ""; } }
            }
            ListView {
                id: todoList
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                spacing: 2
                model: Logic.sortedTodos(IslandTools.todos)
                ScrollBar.vertical: ScrollBar {}
                delegate: RowLayout {
                    id: row
                    required property var modelData
                    width: todoList.width
                    spacing: 8
                    IslandButton {
                        implicitHeight: 32; implicitWidth: 32; leftPadding: 4; rightPadding: 4
                        iconName: row.modelData.done ? "check_circle" : "radio_button_unchecked"
                        Accessible.name: row.modelData.done ? qsTr("Mark not done") : qsTr("Mark done")
                        onClicked: IslandTools.toggleTodo(row.modelData.id)
                    }
                    IslandText { Layout.fillWidth: true; text: row.modelData.text; font.pixelSize: 13; font.strikeout: row.modelData.done; color: row.modelData.done ? IslandTheme.palette.m3outline : IslandTheme.palette.m3onSurface; elide: Text.ElideRight }
                    IslandButton { implicitHeight: 28; implicitWidth: 28; leftPadding: 4; rightPadding: 4; iconName: "close"; Accessible.name: qsTr("Delete task"); onClicked: IslandTools.removeTodo(row.modelData.id) }
                }
                IslandText { anchors.centerIn: parent; visible: !todoList.count; text: qsTr("Nothing to do. Enjoy it."); font.pixelSize: 13; color: IslandTheme.palette.m3onSurfaceVariant }
            }
            RowLayout {
                Layout.fillWidth: true
                IslandText { Layout.fillWidth: true; text: qsTr("%1 open").arg(IslandTools.openTodos); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
                IslandButton { text: qsTr("Clear done"); implicitHeight: 26; visible: IslandTools.todos.length > IslandTools.openTodos; onClicked: IslandTools.clearDone() }
            }
        }

        // World clocks
        ColumnLayout {
            spacing: 8
            Repeater {
                model: IslandTools.clocks
                Rectangle {
                    id: clock
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 70
                    radius: 18
                    color: IslandTheme.palette.card
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                        MaterialIcon { text: clock.modelData.night ? "dark_mode" : "light_mode"; color: clock.modelData.night ? IslandTheme.palette.indigo : IslandTheme.palette.yellow; fontStyle: Tokens.font.icon.medium }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            IslandText { Layout.fillWidth: true; text: clock.modelData.name; font.pixelSize: 14; font.weight: Font.DemiBold }
                            IslandText { Layout.fillWidth: true; text: clock.modelData.day; font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
                        }
                        IslandText { text: clock.modelData.time; font.pixelSize: 28; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // Box breathing, animated only while started and visible.
        ColumnLayout {
            id: breathe
            property bool running
            property double started
            property var state: Logic.breathe(0, 4000)
            Timer {
                interval: 33; repeat: true
                running: breathe.running && root.visible && root.tab === "breathe"
                onTriggered: breathe.state = Logic.breathe(Date.now() - breathe.started, 4000)
            }
            spacing: 8
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Rectangle {
                    anchors.centerIn: parent
                    width: 170; height: 170; radius: 85
                    color: "transparent"
                    border.width: 1; border.color: IslandTheme.palette.divider
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 170 * (breathe.running ? breathe.state.scale : .55); height: width; radius: width / 2
                    color: Qt.alpha(IslandTheme.palette.green, .85)
                }
                IslandText {
                    anchors.centerIn: parent
                    text: breathe.running ? ({ inhale: qsTr("Breathe in"), hold: qsTr("Hold"), exhale: qsTr("Breathe out"), rest: qsTr("Hold") })[breathe.state.phase] : qsTr("Box breathing")
                    font.pixelSize: 14; font.weight: Font.DemiBold; color: "#000000"
                }
            }
            IslandButton {
                Layout.alignment: Qt.AlignHCenter
                text: breathe.running ? qsTr("Stop") : qsTr("Start")
                accent: !breathe.running; accentColour: IslandTheme.palette.green
                implicitHeight: 32; implicitWidth: 110
                onClicked: { breathe.running = !breathe.running; breathe.started = Date.now(); breathe.state = Logic.breathe(0, 4000); }
            }
        }

        // Focus
        ColumnLayout {
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                FocusTile { title: qsTr("Quiet"); iconName: "do_not_disturb_on"; checked: Notifs.dnd; tint: IslandTheme.palette.purple; onClicked: Notifs.dnd = !Notifs.dnd }
                FocusTile { title: qsTr("Presenting"); iconName: "co_present"; checked: IslandTools.presenting; tint: IslandTheme.palette.orange; onClicked: IslandTools.setPresenting(!IslandTools.presenting) }
                FocusTile { title: qsTr("Eye breaks"); iconName: "visibility"; checked: IslandTools.eyeBreakEnabled; tint: IslandTheme.palette.green; onClicked: IslandTools.setEyeBreak(!IslandTools.eyeBreakEnabled) }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: awake.implicitHeight + 28
                radius: 18
                color: IslandTheme.palette.card
                ColumnLayout {
                    id: awake
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        MaterialIcon { text: "coffee"; color: IslandTheme.palette.orange; fontStyle: Tokens.font.icon.small }
                        IslandText { Layout.fillWidth: true; text: qsTr("Keep awake"); font.pixelSize: 13; font.weight: Font.DemiBold }
                        IslandText { text: !IdleInhibitor.enabled ? qsTr("Off") : IslandTools.awakeLeft ? qsTr("%1 left").arg(IslandTools.awakeLeft) : qsTr("Until turned off"); font.pixelSize: 12; color: IdleInhibitor.enabled ? IslandTheme.palette.orange : IslandTheme.palette.m3onSurfaceVariant }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: [{ m: 30, t: "30m" }, { m: 60, t: "1h" }, { m: 120, t: "2h" }, { m: 0, t: "∞" }]
                            IslandButton { required property var modelData; Layout.fillWidth: true; text: modelData.t; implicitHeight: 30; onClicked: IslandTools.keepAwake(modelData.m) }
                        }
                        IslandButton { text: qsTr("Off"); implicitHeight: 30; enabled: IdleInhibitor.enabled; onClicked: IslandTools.stopAwake() }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                MaterialIcon { text: "blur_on"; color: IslandTheme.palette.teal; fontStyle: Tokens.font.icon.small }
                IslandText { Layout.fillWidth: true; text: qsTr("Liquid Glass island"); font.pixelSize: 13 }
                IslandSwitch { checked: IslandTools.glass; Accessible.name: qsTr("Liquid Glass island"); onClicked: IslandTools.setGlass(!IslandTools.glass) }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: IslandTools.eyeBreakEnabled
                IslandText { Layout.fillWidth: true; text: qsTr("Remind me every %1 min, when you are not busy").arg(IslandTools.eyeInterval); font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant }
                IslandButton { iconName: "remove"; implicitHeight: 28; implicitWidth: 32; leftPadding: 5; rightPadding: 5; Accessible.name: qsTr("Shorter interval"); onClicked: IslandTools.setEyeInterval(IslandTools.eyeInterval - 5) }
                IslandButton { iconName: "add"; implicitHeight: 28; implicitWidth: 32; leftPadding: 5; rightPadding: 5; Accessible.name: qsTr("Longer interval"); onClicked: IslandTools.setEyeInterval(IslandTools.eyeInterval + 5) }
            }
            Item { Layout.fillHeight: true }
        }
    }

    component FocusTile: IslandButton {
        id: tile
        required property string title
        property color tint: IslandTheme.palette.accent
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 72
        Accessible.name: qsTr("%1, %2").arg(title).arg(checked ? qsTr("on") : qsTr("off"))
        background: Rectangle {
            radius: 18
            color: tile.hovered || tile.down ? IslandTheme.palette.cardHover : IslandTheme.palette.card
            border.width: tile.activeFocus ? 2 : 0
            border.color: IslandTheme.palette.focus
        }
        contentItem: ColumnLayout {
            spacing: 6
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 34; implicitHeight: 34; radius: 17
                color: tile.checked ? tile.tint : IslandTheme.palette.chip
                Behavior on color { ColorAnimation { duration: 180 * Tokens.anim.durations.scale } }
                MaterialIcon { anchors.centerIn: parent; text: tile.iconName; fill: tile.checked ? 1 : 0; color: "#ffffff"; fontStyle: Tokens.font.icon.small }
            }
            IslandText { Layout.alignment: Qt.AlignHCenter; text: tile.title; font.pixelSize: 11; color: tile.checked ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3onSurfaceVariant }
        }
    }
}
