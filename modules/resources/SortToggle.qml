import QtQuick
import qs.services

// "RAM | CPU" segmented toggle.
Row {
    id: root

    property string key: "ram"
    signal changed(string key)

    spacing: 2

    Repeater {
        model: ["ram", "cpu"]

        Rectangle {
            id: seg

            required property string modelData
            readonly property bool active: root.key === modelData

            width: label.implicitWidth + 16
            height: 22
            radius: 6
            color: active ? ResourcesTheme.track : (area.containsMouse ? ResourcesTheme.hover : "transparent")

            Text {
                id: label
                anchors.centerIn: parent
                text: seg.modelData.toUpperCase()
                color: seg.active ? ResourcesTheme.text : ResourcesTheme.textDim
                font.family: ResourcesTheme.uiFont
                font.pixelSize: 11
                font.weight: Font.Medium
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.key = seg.modelData;
                    root.changed(seg.modelData);
                }
            }
        }
    }
}
