pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property var popouts

    readonly property color phaseColor: {
        switch (Pomodoro.phase) {
        case "shortBreak":
            return Colours.palette.m3tertiary;
        case "longBreak":
            return Colours.palette.m3secondary;
        case "focus":
        default:
            return Colours.palette.m3primary;
        }
    }

    readonly property color phaseContainerColor: {
        switch (Pomodoro.phase) {
        case "shortBreak":
            return Colours.palette.m3tertiaryContainer;
        case "longBreak":
            return Colours.palette.m3secondaryContainer;
        case "focus":
        default:
            return Colours.palette.m3primaryContainer;
        }
    }

    readonly property color onPhaseContainerColor: {
        switch (Pomodoro.phase) {
        case "shortBreak":
            return Colours.palette.m3onTertiaryContainer;
        case "longBreak":
            return Colours.palette.m3onSecondaryContainer;
        case "focus":
        default:
            return Colours.palette.m3onPrimaryContainer;
        }
    }

    implicitWidth: layout.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small
        Layout.preferredWidth: 220

        // Phase badge
        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            radius: Tokens.rounding.full
            color: root.phaseContainerColor
            implicitWidth: phaseLabel.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: phaseLabel.implicitHeight + Tokens.padding.extraSmall * 2

            StyledText {
                id: phaseLabel

                anchors.centerIn: parent
                text: Pomodoro.currentPhaseLabel.toUpperCase()
                font: Tokens.font.label.builders.small.weight(Font.Bold).letterSpacing(1.1).build()
                color: root.onPhaseContainerColor
            }

            Behavior on color {
                CAnim {}
            }
        }

        // Countdown display
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.extraSmall
            text: Pomodoro.formattedTime
            font: Tokens.font.headline.builders.large.weight(Font.Bold).scale(1.2).build()
            color: Pomodoro.paused ? Colours.palette.m3outline : root.phaseColor
            opacity: Pomodoro.paused ? 0.7 : 1.0

            Behavior on color {
                CAnim {}
            }
            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Minimal progress bar
        StyledProgressBar {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 190
            Layout.leftMargin: Tokens.padding.extraSmall
            Layout.rightMargin: Tokens.padding.extraSmall
            Layout.topMargin: Tokens.spacing.extraSmall
            Layout.bottomMargin: Tokens.spacing.small

            implicitHeight: 3
            value: Pomodoro.progress
            fgColour: root.phaseColor
            bgColour: Colours.palette.m3surfaceContainerHighest

            Behavior on fgColour {
                CAnim {}
            }
        }

        // Controls
        // Idle: Start
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 120
            implicitHeight: startBtn.implicitHeight
            visible: !Pomodoro.hasActiveSession

            IconTextButton {
                id: startBtn

                anchors.centerIn: parent
                text: qsTr("Start")
                icon: "play_arrow"
                type: ButtonBase.Filled
                activeColour: root.phaseColor
                inactiveColour: root.phaseColor
                onClicked: Pomodoro.start()
            }
        }

        // Running or Paused: Pause/Resume + Skip, and Reset
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.extraSmall
            visible: Pomodoro.hasActiveSession

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.small

                IconTextButton {
                    text: Pomodoro.running ? qsTr("Pause") : qsTr("Resume")
                    icon: Pomodoro.running ? "pause" : "play_arrow"
                    type: ButtonBase.Filled
                    activeColour: root.phaseColor
                    inactiveColour: root.phaseColor
                    onClicked: {
                        if (Pomodoro.running)
                            Pomodoro.pause();
                        else
                            Pomodoro.resume();
                    }
                }

                IconTextButton {
                    text: qsTr("Skip")
                    icon: "skip_next"
                    type: ButtonBase.Tonal
                    onClicked: Pomodoro.skip()
                }
            }

            IconTextButton {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Reset")
                icon: "restart_alt"
                type: ButtonBase.Text
                onClicked: Pomodoro.reset()
            }
        }

        // Focus cycle status
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("%1 / %2 focus sessions").arg(Pomodoro.cycleCompleted).arg(Pomodoro.longBreakInterval)
                font: Tokens.font.label.builders.small.build()
                color: Colours.palette.m3onSurfaceVariant
            }

            Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: Pomodoro.longBreakInterval

                    Rectangle {
                        required property int index

                        width: 5
                        height: 5
                        radius: 2.5
                        color: index < Pomodoro.cycleCompleted ? root.phaseColor : Colours.palette.m3outlineVariant
                        opacity: index < Pomodoro.cycleCompleted ? 1.0 : 0.4

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }
            }
        }
    }
}
