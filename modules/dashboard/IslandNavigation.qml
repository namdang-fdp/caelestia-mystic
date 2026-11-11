pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.services

// A small island of its own, floating under the main one. Dots stand for
// pages; the current page is a longer capsule. Widths settle with a light
// spring so the capsule feels liquid when pages change.
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
    implicitWidth: pill.width
    implicitHeight: 30
    function pageName(page: string): string {
        return ({ home: qsTr("Home"), controls: qsTr("Controls"), media: qsTr("Media"), timer: qsTr("Timer"), tools: qsTr("Tools"), agent: qsTr("Agent"), shelf: qsTr("Shelf"), clipboard: qsTr("Clipboard"), workspaces: qsTr("Windows"), more: qsTr("More") })[page] ?? page;
    }
    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: dots.implicitWidth + 20 + 34
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
            id: dots
            anchors.verticalCenter: parent.verticalCenter
            x: 10
            Repeater {
                model: root.pages
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
                    Behavior on width { enabled: root.motionScale > 0; SpringAnimation { spring: 3.2 / (root.motionScale * root.motionScale); damping: .3 / root.motionScale; epsilon: .25 } }
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
