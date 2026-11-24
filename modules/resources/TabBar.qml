import QtQuick
import qs.services

// Segmented control: the active tab shows its icon and label, the others the icon alone.
// tabs: [{ id, icon, tint, label }]
Item {
    id: root

    property var tabs: []
    property string current
    signal picked(string id)

    property Item activeItem

    implicitHeight: 36

    Rectangle {
        anchors.fill: parent
        radius: ResourcesTheme.radiusCard
        color: ResourcesTheme.card
    }

    // Sliding highlight behind the active segment.
    Rectangle {
        y: 3
        height: parent.height - 6
        radius: ResourcesTheme.radiusCard - 2
        color: ResourcesTheme.track
        x: root.activeItem ? row.x + root.activeItem.x : 0
        width: root.activeItem ? root.activeItem.width : 0
        visible: root.activeItem !== null

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: row

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: root.tabs

            Item {
                id: seg

                required property var modelData
                readonly property bool active: root.current === modelData.id

                width: active ? tile.width + label.implicitWidth + 26 : 40
                height: root.height - 6

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                onActiveChanged: if (active) root.activeItem = seg
                Component.onCompleted: if (active) root.activeItem = seg

                IconTile {
                    id: tile
                    x: seg.active ? 8 : (seg.width - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    icon: seg.modelData.icon
                    tint: seg.modelData.tint
                }
                Text {
                    id: label
                    anchors.left: tile.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.modelData.label
                    opacity: seg.active ? 1 : 0
                    color: ResourcesTheme.text
                    font.family: ResourcesTheme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.Medium

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(seg.modelData.id)
                }
            }
        }
    }
}
