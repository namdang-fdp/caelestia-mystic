pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.services

// A small island of its own, floating under the main one. Three sections
// (Now, Control, Tools) sit on the left, the current one expanded with its
// name; the dots beside them stand for the pages of that section, the current
// page a longer capsule. Widths settle with a light spring so the capsule
// feels liquid when pages change.
Item {
    id: root
    required property var pages
    required property string currentPage
    property bool pinned
    signal pageRequested(string page)
    signal stepRequested(int direction)
    signal pinToggled
    property real wheelRest
    readonly property real motionScale: Tokens.anim.durations.scale
    readonly property var sections: [
        { id: "now", label: qsTr("Now"), icon: "bolt", pages: ["home", "media", "timer", "agent"] },
        { id: "control", label: qsTr("Control"), icon: "tune", pages: ["controls", "workspaces", "more"] },
        { id: "tools", label: qsTr("Tools"), icon: "build", pages: ["tools", "shelf", "clipboard"] }
    ]
    readonly property var current: sections.find(g => g.pages.includes(currentPage)) ?? sections[0]
    readonly property var sectionPages: current.pages.filter(page => pages.includes(page))
    implicitWidth: pill.width
    implicitHeight: 30
    function pageName(page: string): string {
        return ({ home: qsTr("Home"), controls: qsTr("Controls"), media: qsTr("Media"), timer: qsTr("Timer"), tools: qsTr("Tools"), agent: qsTr("Agent"), shelf: qsTr("Shelf"), clipboard: qsTr("Clipboard"), workspaces: qsTr("Windows"), more: qsTr("More") })[page] ?? page;
    }
    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: row.implicitWidth + 16 + 34
        height: 30
        radius: 15
        color: "#e6120f18"
        border.width: 1
        border.color: "#26ffffff"
        // Scrolling over the dots turns pages.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? -event.angleDelta.x : -event.angleDelta.y;
                root.wheelRest += delta;
                if (Math.abs(root.wheelRest) >= 120) { root.stepRequested(root.wheelRest > 0 ? 1 : -1); root.wheelRest = 0; }
            }
        }
        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            spacing: 4
            Repeater {
                model: root.sections
                IslandButton {
                    id: section
                    required property var modelData
                    readonly property bool here: modelData.id === root.current.id
                    objectName: "islandSection_" + modelData.id
                    implicitHeight: 30
                    leftPadding: here ? 10 : 7; rightPadding: here ? 10 : 7
                    background: Rectangle {
                        y: 3
                        height: 24
                        radius: 12
                        color: section.here ? IslandTheme.palette.m3surfaceContainerHighest : section.hovered ? IslandTheme.palette.m3surfaceContainerHigh : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 * root.motionScale } }
                    }
                    iconName: modelData.icon
                    text: here ? modelData.label : ""
                    checked: here
                    Accessible.name: modelData.label
                    onClicked: if (!here) root.pageRequested(modelData.pages.find(page => root.pages.includes(page)))
                }
            }
            Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: "#33ffffff" }
            Row {
                id: dots
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                model: root.sectionPages
                IslandButton {
                    id: dot
                    required property string modelData
                    readonly property bool current: modelData === root.currentPage
                    objectName: "islandPageDot_" + modelData
                    implicitHeight: 30
                    leftPadding: 0; rightPadding: 0
                    implicitWidth: (current ? 26 : 8) + 12
                    width: implicitWidth
                    background: null
                    Accessible.name: root.pageName(modelData)
                    Accessible.role: Accessible.PageTab
                    Accessible.selected: current
                    ToolTip.visible: hovered
                    ToolTip.text: root.pageName(modelData)
                    ToolTip.delay: 350
                    onClicked: root.pageRequested(modelData)
                    // Overshoots slightly, then settles.
                    Behavior on width { enabled: root.motionScale > 0; SpringAnimation { spring: 3.2 / (root.motionScale * root.motionScale); damping: .45 / root.motionScale; epsilon: .1 } }
                    contentItem: Item {
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.max(8, dot.width - 12); height: 8; radius: 4
                            color: dot.current ? "#ffffff" : dot.hovered || dot.activeFocus ? "#b3ffffff" : "#59ffffff"
                            Behavior on color { ColorAnimation { duration: 140 * root.motionScale } }
                        }
                    }
                }
                }
            }
        }
        IslandButton {
            objectName: "islandPinButton"
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            implicitWidth: 26; implicitHeight: 26; leftPadding: 0; rightPadding: 0
            iconName: root.pinned ? "keep" : "keep_off"
            checked: root.pinned
            Accessible.name: root.pinned ? qsTr("Unpin island") : qsTr("Keep island open")
            ToolTip.visible: hovered; ToolTip.text: Accessible.name; ToolTip.delay: 350
            onClicked: root.pinToggled()
        }
    }
}
