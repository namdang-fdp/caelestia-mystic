pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services

StyledWindow {
    id: root

    required property var controller

    readonly property real chipWidth: Math.min(390, Math.max(245, chipRow.implicitWidth + contentItem.Tokens.padding.large * 2))
    readonly property real chipHeight: 42
    readonly property real safeMargin: Math.max(16, contentItem.Config.border.thickness + 10)
    readonly property bool overtime: LeetCodeTimer.elapsedDuration >= LeetCodeTimer.targetDuration
    readonly property bool significantlyOvertime: LeetCodeTimer.elapsedDuration >= LeetCodeTimer.targetDuration * 1.25
    readonly property color accent: significantlyOvertime
        ? Colours.palette.m3error
        : overtime ? Colours.palette.m3tertiary : Colours.palette.m3primary

    name: "leetcode-timer-chip"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.margins.top: safeMargin
    WlrLayershell.margins.right: safeMargin

    anchors.top: true
    anchors.right: true

    implicitWidth: chipWidth
    implicitHeight: chipHeight

    StyledRect {
        id: chip

        anchors.fill: parent
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surface
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.42)

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
        }

        StateLayer {
            radius: parent.radius
            color: root.accent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.controller.open()
        }

        RowLayout {
            id: chipRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 28
                implicitHeight: 28
                radius: Tokens.rounding.full
                color: Qt.alpha(root.accent, 0.18)

                StyledText {
                    anchors.centerIn: parent
                    text: "LC"
                    color: root.accent
                    font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                }
            }

            StyledText {
                Layout.maximumWidth: 220
                text: {
                    const number = LeetCodeTimer.problemNumber ? `#${LeetCodeTimer.problemNumber}` : qsTr("LeetCode");
                    const title = LeetCodeTimer.problemTitle || qsTr("Session");
                    return `${number} · ${title}`;
                }
                elide: Text.ElideRight
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: LeetCodeTimer.status === "paused"
                text: "pause"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: LeetCodeTimer.formatDuration(LeetCodeTimer.elapsedDuration)
                color: root.accent
                font: Tokens.font.mono.builders.small.weight(Font.DemiBold).build()
            }
        }
    }
}
