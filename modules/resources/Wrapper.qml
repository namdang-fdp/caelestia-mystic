pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.components
import qs.services

// Bottom-left drawer. Springs in from the left only when screenState.resources is set (see
// Interactions.qml), is as tall as its content (up to 80% of the screen) and springs to the new
// height when the content changes, like the island.
Item {
    id: root

    required property ScreenState screenState

    // Trigger: a thin strip along the bottom edge in the bottom-left corner (the mirror of the
    // utilities corner at the bottom right).
    readonly property int activationWidth: 96
    readonly property int activationHeight: 6
    readonly property int margin: 12
    readonly property int cardWidth: 400

    readonly property bool shouldBeActive: screenState.resources
    // 0 = shown, 1 = hidden. A spring, so opening overshoots a touch before settling.
    property real offsetScale: shouldBeActive ? 0 : 1

    readonly property real maxHeight: Math.round((parent?.height ?? 0) * 0.8)
    readonly property real contentHeight: loader.item ? loader.item.implicitHeight : 0
    readonly property real targetHeight: Math.min(contentHeight > 0 ? contentHeight : 360, maxHeight)
    property bool heightGrowing: true

    // Touching the singletons starts their always-on sampling at shell start.
    Component.onCompleted: {
        ResourcesHistory.ready;
        ResourcesAlerts.loaded;
    }

    onTargetHeightChanged: heightGrowing = targetHeight > implicitHeight

    visible: offsetScale < 1
    anchors.leftMargin: (-implicitWidth - 5) * offsetScale
    implicitWidth: cardWidth + margin
    implicitHeight: targetHeight
    opacity: Math.max(0, Math.min(1, 1 - offsetScale))
    scale: 1 - 0.04 * Math.max(0, Math.min(1, offsetScale))
    transformOrigin: Item.Left

    Behavior on offsetScale {
        SpringAnimation {
            spring: root.shouldBeActive ? 3.5 : 5
            damping: root.shouldBeActive ? 0.30 : 0.9
            epsilon: 0.0005
        }
    }
    // Same spring the island uses: a little overshoot while growing, damped harder while shrinking.
    Behavior on implicitHeight {
        SpringAnimation {
            spring: 4
            damping: root.heightGrowing ? 0.32 : 0.45
            epsilon: 0.25
        }
    }

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur: 34
        spread: -10
        offset.y: 12
        color: Qt.alpha("black", 0.5)
    }

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.leftMargin: root.margin
        radius: ResourcesTheme.radius
        color: ResourcesTheme.glass
        border.width: 1
        border.color: ResourcesTheme.border

        // Light from above: a soft highlight that fades out over the top third.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: ResourcesTheme.glassHighlight
                }
                GradientStop {
                    position: 0.35
                    color: "transparent"
                }
            }
        }

        Loader {
            id: loader
            anchors.fill: parent
            active: root.shouldBeActive || root.visible
            sourceComponent: Content {}
        }
    }
}
