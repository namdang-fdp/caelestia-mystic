import QtQuick
import QtQuick.Layouts
import qs.services
import "../dashboard/helpers/ResourceLogic.js" as Logic

// Compact stat: title, a big value, and an autoscaled sparkline so small movements still show.
Card {
    id: root

    property string value
    property string detail
    property var values: []
    property color tint: ResourcesTheme.ok
    property real minSpan: 10
    readonly property var range: Logic.autoRange(values, minSpan, 100)

    Text {
        text: root.value
        color: ResourcesTheme.text
        font.family: ResourcesTheme.uiFont
        font.pixelSize: 22
        font.weight: Font.DemiBold
        font.features: ({"tnum": 1})
    }
    Text {
        visible: root.detail !== ""
        text: root.detail
        color: ResourcesTheme.textDim
        font.family: ResourcesTheme.uiFont
        font.pixelSize: 11
        font.features: ({"tnum": 1})
    }
    Sparkline {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        values: root.values
        tint: root.tint
        floor: root.range.floor
        ceiling: root.range.ceiling
    }
}
