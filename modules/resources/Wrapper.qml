pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services

// Left-edge drawer. Slides in from the left only when screenState.resources is set
// (see Interactions.qml); mirrors modules/utilities/Wrapper.qml.
Item {
    id: root

    required property ScreenState screenState

    // Trigger strip: leftmost px, within this band of the screen height.
    readonly property int activationWidth: 4
    readonly property real bandStart: 0.15
    readonly property real bandEnd: 0.85
    readonly property int margin: 12
    readonly property int cardWidth: 400

    readonly property bool shouldBeActive: screenState.resources
    property real offsetScale: shouldBeActive ? 0 : 1

    // Touching the singleton starts its always-on sampling at shell start.
    Component.onCompleted: ResourcesHistory.ready

    visible: offsetScale < 1
    anchors.leftMargin: (-implicitWidth - 5) * offsetScale
    implicitWidth: cardWidth + margin
    implicitHeight: Math.round((parent?.height ?? 0) * 0.8)
    opacity: 1 - offsetScale

    // Standard easing: a gentle ease-out with no overshoot.
    Behavior on offsetScale {
        Anim {
            type: Anim.Standard
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: root.margin
        radius: ResourcesTheme.radius
        color: ResourcesTheme.surface
        border.width: 1
        border.color: ResourcesTheme.border

        Loader {
            anchors.fill: parent
            active: root.shouldBeActive || root.visible
            sourceComponent: Content {}
        }
    }
}
