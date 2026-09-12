pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    readonly property bool editorActive: numberField.activeFocus || titleField.activeFocus || targetField.activeFocus
    readonly property int verticalPadding: Tokens.padding.extraLarge
    readonly property bool setupVisible: LeetCodeTimer.status === "idle"
    readonly property var visibleRecentSessions: LeetCodeTimer.recentSessions.slice(0, 3)
    readonly property bool significantlyOvertime: LeetCodeTimer.elapsedDuration >= LeetCodeTimer.targetDuration * 1.25
    readonly property bool overtime: LeetCodeTimer.elapsedDuration >= LeetCodeTimer.targetDuration
    readonly property color timerAccent: significantlyOvertime
        ? Colours.palette.m3error
        : overtime ? Colours.palette.m3tertiary : Colours.palette.m3primary
    property string armedAction

    implicitHeight: layout.implicitHeight + verticalPadding * 2

    signal closeRequested

    function syncEditors(): void {
        if (!numberField.activeFocus)
            numberField.text = LeetCodeTimer.problemNumber;
        if (!titleField.activeFocus)
            titleField.text = LeetCodeTimer.problemTitle;
        if (!targetField.activeFocus)
            targetField.text = (LeetCodeTimer.targetDuration / 60000).toString();
    }

    function commitEditors(): bool {
        LeetCodeTimer.setProblem(numberField.text, titleField.text);
        if (!LeetCodeTimer.setTargetMinutes(targetField.text)) {
            targetField.isError = true;
            return false;
        }
        return true;
    }

    function arm(action: string): void {
        if (armedAction === action) {
            armedAction = "";
            if (action === "reset")
                LeetCodeTimer.resetSession(false);
            else if (action === "giveup")
                LeetCodeTimer.complete("GIVE_UP");
            return;
        }
        armedAction = action;
        disarmTimer.restart();
    }

    function checkpointText(name: string): string {
        const elapsed = LeetCodeTimer.checkpointElapsed(name);
        if (elapsed < 0)
            return name;
        if (name === "Debug") {
            const code = LeetCodeTimer.checkpointElapsed("Code");
            if (code >= 0)
                return `${name} +${LeetCodeTimer.formatDuration(Math.max(0, elapsed - code))}`;
        }
        return `${name} ${LeetCodeTimer.formatDuration(elapsed)}`;
    }

    function resultLabel(result: string): string {
        return result === "AC" ? qsTr("AC") : qsTr("Give Up");
    }

    function targetMinutesLabel(): string {
        const minutes = LeetCodeTimer.targetDuration / 60000;
        return Number.isInteger(minutes) ? minutes.toString() : minutes.toFixed(1);
    }

    Timer {
        id: disarmTimer

        interval: 3200
        onTriggered: root.armedAction = ""
    }

    Connections {
        target: LeetCodeTimer

        function onProblemNumberChanged(): void {
            if (!numberField.activeFocus)
                numberField.text = LeetCodeTimer.problemNumber;
        }

        function onProblemTitleChanged(): void {
            if (!titleField.activeFocus)
                titleField.text = LeetCodeTimer.problemTitle;
        }

        function onTargetDurationChanged(): void {
            if (!targetField.activeFocus)
                targetField.text = (LeetCodeTimer.targetDuration / 60000).toString();
        }
    }

    Component.onCompleted: syncEditors()

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.verticalPadding
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 34
                implicitHeight: 34
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "timer"
                    fill: 1
                    color: Colours.palette.m3onPrimaryContainer
                    fontStyle: Tokens.font.icon.medium
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("LEETCODE SESSION")
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).letterSpacing(1.1).build()
            }

            StyledText {
                visible: LeetCodeTimer.status === "paused"
                text: qsTr("Paused · saved")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            IconButton {
                implicitWidth: implicitHeight
                implicitHeight: 34
                icon: "close"
                type: IconButton.Tonal
                onClicked: root.closeRequested()
            }
        }

        RowLayout {
            id: setupRow

            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 50 : 0
            visible: root.setupVisible
            spacing: Tokens.spacing.extraSmall

            StyledTextField {
                id: numberField

                Layout.preferredWidth: 78
                Layout.preferredHeight: 50
                placeholderText: qsTr("#")
                inputMethodHints: Qt.ImhDigitsOnly
                validate: /^\d+$/
                emptyIsValid: true
                onEditingFinished: LeetCodeTimer.setProblem(text, titleField.text)
            }

            StyledTextField {
                id: titleField

                Layout.fillWidth: true
                Layout.minimumWidth: 150
                Layout.preferredHeight: 50
                placeholderText: qsTr("Problem title")
                onEditingFinished: LeetCodeTimer.setProblem(numberField.text, text)
            }

            Repeater {
                model: ["Easy", "Medium", "Hard"]

                TextButton {
                    required property string modelData

                    implicitHeight: 32
                    horizontalPadding: Tokens.padding.small
                    verticalPadding: Tokens.padding.extraSmall
                    text: modelData
                    font: Tokens.font.label.small
                    checked: LeetCodeTimer.difficulty === modelData
                    type: TextButton.Tonal
                    onClicked: LeetCodeTimer.setDifficulty(modelData)
                }
            }

            StyledTextField {
                id: targetField

                Layout.preferredWidth: 82
                Layout.preferredHeight: 50
                placeholderText: qsTr("Target")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validate: /^\d+(\.\d+)?$/
                emptyIsValid: false
                onEditingFinished: {
                    if (!LeetCodeTimer.setTargetMinutes(text))
                        isError = true;
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: implicitHeight
                implicitHeight: 36
                icon: "find_in_page"
                type: IconButton.Tonal
                onClicked: LeetCodeTimer.prefillFromActiveWindow(true)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 38 : 0
            visible: !root.setupVisible
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: {
                    const number = LeetCodeTimer.problemNumber ? `#${LeetCodeTimer.problemNumber}` : qsTr("LeetCode");
                    const title = LeetCodeTimer.problemTitle || qsTr("Untitled problem");
                    return `${number}  ${title}`;
                }
                elide: Text.ElideRight
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
            }

            StyledRect {
                implicitWidth: difficultyLabel.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: 28
                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                StyledText {
                    id: difficultyLabel

                    anchors.centerIn: parent
                    text: LeetCodeTimer.difficulty
                    color: Colours.palette.m3onSecondaryContainer
                    font: Tokens.font.label.small
                }
            }

            StyledText {
                text: qsTr("Target %1m").arg(root.targetMinutesLabel())
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            StyledRect {
                visible: LeetCodeTimer.status === "finished"
                implicitWidth: resultSummary.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: 28
                radius: Tokens.rounding.full
                color: LeetCodeTimer.lastResult === "AC"
                    ? Colours.palette.m3primaryContainer : Colours.palette.m3errorContainer

                StyledText {
                    id: resultSummary

                    anchors.centerIn: parent
                    text: root.resultLabel(LeetCodeTimer.lastResult)
                    color: LeetCodeTimer.lastResult === "AC"
                        ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onErrorContainer
                    font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                anchors.topMargin: Tokens.padding.small
                anchors.bottomMargin: Tokens.padding.small
                spacing: 1

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: LeetCodeTimer.formatDuration(LeetCodeTimer.elapsedDuration)
                    color: root.timerAccent
                    font: Tokens.font.mono.builders.large.size(43).weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Target %1 · %2")
                        .arg(LeetCodeTimer.formatDuration(LeetCodeTimer.targetDuration))
                        .arg(LeetCodeTimer.status.charAt(0).toUpperCase() + LeetCodeTimer.status.slice(1))
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    value: LeetCodeTimer.targetProgress
                    fgColour: root.timerAccent
                    bgColour: Colours.tPalette.m3surfaceContainerHighest
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: Tokens.spacing.small

            IconTextButton {
                Layout.fillWidth: true
                implicitHeight: 38
                verticalPadding: Tokens.padding.extraSmall
                icon: LeetCodeTimer.status === "running" ? "pause" : "play_arrow"
                text: LeetCodeTimer.status === "running" ? qsTr("Pause")
                    : LeetCodeTimer.status === "paused" ? qsTr("Resume")
                    : LeetCodeTimer.status === "finished" ? qsTr("Start new") : qsTr("Start")
                disabled: !LeetCodeTimer.storageReady
                onClicked: {
                    if (root.commitEditors())
                        LeetCodeTimer.startOrToggle();
                }
            }

            IconTextButton {
                Layout.fillWidth: true
                implicitHeight: 38
                verticalPadding: Tokens.padding.extraSmall
                icon: "check_circle"
                text: qsTr("AC")
                type: IconTextButton.Tonal
                disabled: !LeetCodeTimer.hasActiveSession
                inactiveColour: Colours.palette.m3primaryContainer
                inactiveOnColour: Colours.palette.m3onPrimaryContainer
                onClicked: LeetCodeTimer.complete("AC")
            }

            IconTextButton {
                Layout.fillWidth: true
                implicitHeight: 38
                verticalPadding: Tokens.padding.extraSmall
                icon: root.armedAction === "giveup" ? "warning" : "flag"
                text: root.armedAction === "giveup" ? qsTr("Confirm") : qsTr("Give Up")
                type: IconTextButton.Tonal
                disabled: !LeetCodeTimer.hasActiveSession
                inactiveColour: Qt.alpha(Colours.palette.m3errorContainer, 0.78)
                inactiveOnColour: Colours.palette.m3onErrorContainer
                onClicked: root.arm("giveup")
            }

            IconButton {
                implicitWidth: implicitHeight
                implicitHeight: 38
                icon: root.armedAction === "reset" ? "warning" : "restart_alt"
                type: IconButton.Tonal
                disabled: LeetCodeTimer.status === "idle" && LeetCodeTimer.elapsedDuration === 0
                onClicked: root.arm("reset")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("Checkpoints")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            Repeater {
                model: ["Idea", "Code", "Debug"]

                TextButton {
                    required property string modelData

                    implicitHeight: 32
                    horizontalPadding: Tokens.padding.medium
                    verticalPadding: Tokens.padding.extraSmall
                    text: root.checkpointText(modelData)
                    font: Tokens.font.label.small
                    type: TextButton.Tonal
                    disabled: !LeetCodeTimer.hasActiveSession || LeetCodeTimer.checkpointElapsed(modelData) >= 0
                    onClicked: LeetCodeTimer.addCheckpoint(modelData)
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                Stat {
                    Layout.fillWidth: true
                    title: qsTr("Today")
                    value: qsTr("%1 AC").arg(LeetCodeTimer.acCountToday)
                }

                Stat {
                    Layout.fillWidth: true
                    title: qsTr("Avg")
                    value: LeetCodeTimer.formatDuration(LeetCodeTimer.averageAcDurationToday)
                }

                Stat {
                    Layout.fillWidth: true
                    title: qsTr("PB")
                    value: LeetCodeTimer.formatDuration(LeetCodeTimer.personalBest)
                }

                Stat {
                    Layout.fillWidth: true
                    title: qsTr("Attempts")
                    value: LeetCodeTimer.attemptCount.toString()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20

            StyledText {
                text: qsTr("Recent sessions")
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: root.armedAction
                    ? qsTr("Click %1 again to confirm").arg(root.armedAction === "reset" ? qsTr("reset") : qsTr("Give Up"))
                    : qsTr("Space start/pause · Esc close")
                color: root.armedAction ? Colours.palette.m3error : Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: root.visibleRecentSessions.length === 0
                ? 68 : root.visibleRecentSessions.length * 28 + Tokens.padding.small * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    Layout.fillHeight: true
                    visible: root.visibleRecentSessions.length === 0
                    text: qsTr("No sessions yet · start when you're ready")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }

                Repeater {
                    model: root.visibleRecentSessions

                    RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.preferredWidth: 48
                            text: modelData.problemNumber ? `#${modelData.problemNumber}` : "—"
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.mono.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.title || qsTr("Untitled problem")
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.preferredWidth: 62
                            text: root.resultLabel(modelData.result)
                            horizontalAlignment: Text.AlignRight
                            color: modelData.result === "AC" ? Colours.palette.m3primary : Colours.palette.m3error
                            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                        }

                        StyledText {
                            Layout.preferredWidth: 56
                            text: LeetCodeTimer.formatDuration(modelData.totalElapsedDuration)
                            horizontalAlignment: Text.AlignRight
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.mono.small
                        }
                    }
                }
            }
        }
    }

    component Stat: ColumnLayout {
        required property string title
        required property string value

        spacing: 0

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: parent.title
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: parent.value
            color: Colours.palette.m3onSurface
            font: Tokens.font.mono.builders.small.weight(Font.Medium).build()
        }
    }
}
