import QtQuick
import Quickshell

PersistentProperties {
    property list<string> expandedNotifs: []
    property string textFamily: ""
    function textFont(base: font): font {
        return textFamily ? Qt.font({family: textFamily, pixelSize: base.pixelSize, weight: base.weight, italic: base.italic, letterSpacing: base.letterSpacing}) : base;
    }

    reloadableId: "sidebar"
}
