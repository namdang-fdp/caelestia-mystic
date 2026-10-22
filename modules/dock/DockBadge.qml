import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// macOS style notification badge, sized relative to the icon so it scales with magnification
Rectangle {
    id: root

    property int count
    property real baseSize
    readonly property bool dot: DockConfig.badgeStyle === "dot"
    readonly property string text: count > 99 ? "99+" : count.toString()

    implicitHeight: dot ? baseSize * 0.55 : baseSize
    implicitWidth: dot ? implicitHeight : Math.max(implicitHeight, label.implicitWidth + baseSize * 0.5)
    radius: height / 2
    color: "#ff453a"
    border.width: Math.max(1, baseSize * 0.05)
    border.color: Qt.alpha("#000000", 0.08)

    scale: count > 0 ? 1 : 0
    opacity: count > 0 ? 1 : 0
    transformOrigin: Item.Center

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.FastEffects
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.FastSpatial
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        visible: !root.dot
        text: root.text
        color: "#ffffff"
        font.family: Tokens.font.body.small.family
        font.pixelSize: Math.max(1, root.baseSize * 0.6)
        font.weight: Font.DemiBold
        renderType: Text.QtRendering
    }
}
