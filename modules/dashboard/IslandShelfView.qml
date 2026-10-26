pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import "helpers/ActivityLogic.js" as Logic

// Shelf page: files dropped on the island, ready to drag back out or open.
Item {
    id: root
    // A file is being dragged over the island right now.
    property bool dropActive
    // A shelf row is being dragged out; keeps the island open meanwhile.
    readonly property bool exporting: list.exportingCount > 0
    readonly property int visibleRows: Math.min(4, IslandShelf.count)
    signal closeRequested
    implicitHeight: IslandShelf.count ? visibleRows * 56 - 4 + 30 : 132

    // Empty shelf, or a file hovering over it: the drop zone.
    Rectangle {
        id: dropZone
        anchors.fill: IslandShelf.count ? list : parent
        anchors.bottomMargin: IslandShelf.count ? 0 : 22
        visible: !IslandShelf.count || root.dropActive
        z: 1
        radius: 16
        // Over a populated shelf the zone darkens the list beneath it.
        color: root.dropActive ? IslandShelf.count ? "#d10a0e18" : "#14ffffff" : "#08ffffff"
        scale: root.dropActive ? 1.02 : 1
        Behavior on color { ColorAnimation { duration: 200 * Tokens.anim.durations.scale } }
        Behavior on scale { NumberAnimation { duration: 320 * Tokens.anim.durations.scale; easing.type: Easing.OutBack } }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.dropActive ? "#ccffffff" : "#4dffffff"
                strokeWidth: 1.4
                strokeStyle: ShapePath.DashLine
                dashPattern: [4, 3]
                fillColor: "transparent"
                PathRectangle { x: .7; y: .7; width: dropZone.width - 1.4; height: dropZone.height - 1.4; radius: dropZone.radius }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 4
            IslandText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dropActive ? qsTr("Release to add") : qsTr("Drop files here")
                font.pixelSize: 14; font.weight: Font.DemiBold
                color: root.dropActive ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3onSurfaceVariant
            }
            IslandText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !IslandShelf.count && !root.dropActive
                text: qsTr("Drag files onto the island to keep them handy")
                font.pixelSize: 11
                color: IslandTheme.palette.m3outline
            }
        }
    }
    ListView {
        id: list
        property int exportingCount
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top; bottomMargin: 8 }
        visible: IslandShelf.count > 0
        opacity: root.dropActive ? .25 : 1
        Behavior on opacity { NumberAnimation { duration: 160 * Tokens.anim.durations.scale } }
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel { values: IslandShelf.items; objectProp: "path" }
        add: Transition { NumberAnimation { properties: "opacity,scale"; from: .6; to: 1; duration: 220 * Tokens.anim.durations.scale; easing.type: Easing.OutBack } }
        remove: Transition { NumberAnimation { properties: "opacity"; to: 0; duration: 140 * Tokens.anim.durations.scale } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: 200 * Tokens.anim.durations.scale; easing.type: Easing.OutCubic } }
        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property string kind: Logic.fileKind(modelData.name, modelData.isDir)
            readonly property bool image: ["PNG", "JPG", "JPEG", "WEBP", "GIF", "BMP", "AVIF", "SVG"].includes(kind)
            property url dragImage
            width: list.width
            height: 52
            radius: 14
            color: tap.pressed ? IslandTheme.palette.cardHover : rowHover.hovered ? IslandTheme.palette.card : "transparent"
            Behavior on color { ColorAnimation { duration: 120 * Tokens.anim.durations.scale } }

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": IslandShelf.url(modelData.path) + "\r\n" })
            Drag.imageSource: dragImage
            Drag.hotSpot: Qt.point(26, 26)
            Drag.active: drag.active
            DragHandler {
                id: drag
                target: null
                onActiveChanged: list.exportingCount += active ? 1 : -1
            }
            HoverHandler {
                id: rowHover
                cursorShape: Qt.PointingHandCursor
                // The drag image is a snapshot of the row, taken before it can be dragged.
                onHoveredChanged: if (hovered && !row.dragImage.toString()) row.grabToImage(r => row.dragImage = r.url)
            }
            TapHandler {
                id: tap
                onTapped: { IslandShelf.open(row.modelData.path); root.closeRequested(); }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 12
                ClippingRectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    radius: 9
                    color: IslandTheme.palette.chip
                    IslandText {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        horizontalAlignment: Text.AlignHCenter
                        visible: thumb.status !== Image.Ready
                        text: row.kind === "Folder" ? "DIR" : row.kind.slice(0, 4)
                        font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: .4
                        color: IslandTheme.palette.m3onSurfaceVariant
                    }
                    Image {
                        id: thumb
                        anchors.fill: parent
                        source: row.image ? IslandShelf.url(row.modelData.path) : ""
                        sourceSize: Qt.size(72, 72)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 * Tokens.anim.durations.scale } }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    IslandText { Layout.fillWidth: true; text: row.modelData.name; elide: Text.ElideMiddle; font.pixelSize: 13; font.weight: Font.Medium }
                    IslandText {
                        Layout.fillWidth: true
                        text: row.modelData.isDir ? qsTr("Folder") : [Logic.formatBytes(row.modelData.size), row.kind].filter(Boolean).join(" · ")
                        font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant
                    }
                }
                IslandButton {
                    iconName: "close"
                    opacity: rowHover.hovered ? 1 : 0
                    Accessible.name: qsTr("Remove %1 from Shelf").arg(row.modelData.name)
                    onClicked: IslandShelf.remove(row.modelData.path)
                }
            }
        }
    }
    RowLayout {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 4 }
        height: 22
        IslandText {
            Layout.fillWidth: true
            text: IslandShelf.count ? qsTr("Drag out anytime · click to open") : qsTr("Files stay where they are; the shelf only keeps a link")
            font.pixelSize: 11; color: IslandTheme.palette.m3outline
            elide: Text.ElideRight
        }
        IslandButton {
            visible: IslandShelf.count > 0
            implicitHeight: 22; leftPadding: 8; rightPadding: 8
            Accessible.name: qsTr("Remove all files from Shelf")
            onClicked: IslandShelf.clear()
            contentItem: IslandText { text: qsTr("Clear"); font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant }
        }
    }
}
