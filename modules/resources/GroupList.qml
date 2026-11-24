import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import "../dashboard/helpers/ResourceLogic.js" as Logic

// Processes grouped by app (top 8, sort by RAM or CPU). Tap a group to see its biggest processes;
// your own, non-protected ones can be stopped.
Card {
    id: root

    property string sortKey: "ram"
    property string openGroup: ""
    readonly property var rows: Logic.sortGroups(Resources.groups, sortKey).slice(0, 8)

    title: "Processes"

    RowLayout {
        Layout.fillWidth: true
        Item {
            Layout.fillWidth: true
        }
        SortToggle {
            key: root.sortKey
            onChanged: key => root.sortKey = key
        }
    }

    Repeater {
        model: root.rows

        ColumnLayout {
            id: group

            required property var modelData
            readonly property bool open: root.openGroup === modelData.name

            Layout.fillWidth: true
            spacing: 2

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: ResourcesTheme.radiusControl
                color: headArea.containsMouse ? ResourcesTheme.hover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 8

                    MaterialIcon {
                        text: "chevron_right"
                        color: ResourcesTheme.textDim
                        fill: 0
                        fontStyle.pointSize: 12
                        rotation: group.open ? 90 : 0
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: group.modelData.name
                        elide: Text.ElideRight
                        color: ResourcesTheme.text
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 13
                    }
                    Text {
                        text: group.modelData.count + "p"
                        color: ResourcesTheme.textTertiary
                        font.family: ResourcesTheme.numFont
                        font.pixelSize: 11
                        font.features: ({"tnum": 1})
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignRight
                    }
                    Text {
                        text: Math.round(group.modelData.cpu_percent) + "%"
                        color: root.sortKey === "cpu" ? ResourcesTheme.text : ResourcesTheme.textDim
                        font.family: ResourcesTheme.numFont
                        font.pixelSize: 12
                        font.features: ({"tnum": 1})
                        Layout.preferredWidth: 38
                        horizontalAlignment: Text.AlignRight
                    }
                    Text {
                        text: Logic.formatKb(group.modelData.ram_kb)
                        color: root.sortKey === "ram" ? ResourcesTheme.text : ResourcesTheme.textDim
                        font.family: ResourcesTheme.numFont
                        font.pixelSize: 12
                        font.features: ({"tnum": 1})
                        Layout.preferredWidth: 62
                        horizontalAlignment: Text.AlignRight
                    }
                }
                MouseArea {
                    id: headArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openGroup = group.open ? "" : group.modelData.name
                }
            }

            Repeater {
                model: group.open ? group.modelData.top : []

                RowLayout {
                    id: proc

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.leftMargin: 26
                    Layout.rightMargin: 4
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: proc.modelData.name
                        elide: Text.ElideRight
                        color: ResourcesTheme.text
                        font.family: ResourcesTheme.uiFont
                        font.pixelSize: 12
                    }
                    Text {
                        text: proc.modelData.pid
                        color: ResourcesTheme.textTertiary
                        font.family: ResourcesTheme.numFont
                        font.pixelSize: 11
                        font.features: ({"tnum": 1})
                    }
                    Text {
                        text: Logic.formatKb(proc.modelData.ram_kb)
                        color: ResourcesTheme.textDim
                        font.family: ResourcesTheme.numFont
                        font.pixelSize: 12
                        font.features: ({"tnum": 1})
                        Layout.preferredWidth: 58
                        horizontalAlignment: Text.AlignRight
                    }
                    // Stop shows only while the row is hovered (or armed), to keep the list calm.
                    Item {
                        implicitWidth: 38
                        implicitHeight: 22
                        opacity: rowHover.hovered || stopButton.armed ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                        StopButton {
                            id: stopButton
                            anchors.right: parent.right
                            visible: proc.modelData.own && !Logic.isProtected(proc.modelData.name)
                            key: "pid:" + proc.modelData.pid + ":" + proc.modelData.start
                            onConfirmed: ResourcesActions.stop(proc.modelData.pid, proc.modelData.start)
                        }
                    }
                    HoverHandler {
                        id: rowHover
                    }
                }
            }
        }
    }
}
