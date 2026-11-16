import QtQuick
import QtQuick.Layouts
import qs.services

// A value and its recent history: title and value on top, sparkline below.
Card {
    id: root

    property string value
    property string detail
    property var values: []
    property color tint: ResourcesTheme.ok

    trailing: value

    Sparkline {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        values: root.values
        tint: root.tint
    }
    Text {
        visible: root.detail !== ""
        text: root.detail
        color: ResourcesTheme.textDim
        font.family: ResourcesTheme.uiFont
        font.pixelSize: 11
        font.features: ({"tnum": 1})
    }
}
