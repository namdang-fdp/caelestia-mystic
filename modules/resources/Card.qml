import QtQuick
import QtQuick.Layouts
import qs.services

// Grouped card (macOS "inset group"): optional title row, content goes in the default slot.
Rectangle {
    id: root

    default property alias content: slot.data
    property string title
    property string trailing

    implicitHeight: layout.implicitHeight + 24
    radius: ResourcesTheme.radiusCard
    color: ResourcesTheme.card

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        RowLayout {
            visible: root.title !== "" || root.trailing !== ""
            Layout.fillWidth: true
            Text {
                text: root.title
                color: ResourcesTheme.textDim
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: root.trailing
                color: ResourcesTheme.text
                font.family: ResourcesTheme.numFont
                font.pixelSize: 13
                font.features: ({"tnum": 1})
            }
        }
        ColumnLayout {
            id: slot
            Layout.fillWidth: true
            spacing: 6
        }
    }
}
