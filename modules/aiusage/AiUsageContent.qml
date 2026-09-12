pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property var service

    readonly property int contentPadding: Tokens.padding.medium
    implicitHeight: contentLayout.implicitHeight + contentPadding * 2

    function formatPlan(plan: string): string {
        if (!plan)
            return qsTr("Plan unavailable");
        return plan.charAt(0).toUpperCase() + plan.slice(1);
    }

    function formatPercent(percent: real): string {
        const rounded = Math.round(percent);
        if (Math.abs(percent - rounded) < 0.005)
            return `${rounded}`;
        const oneDecimal = Math.round(percent * 10) / 10;
        if (percent < 100 && oneDecimal >= 100)
            return percent.toFixed(2);
        return oneDecimal.toFixed(1);
    }

    function resetCountdown(resetAt: var): string {
        if (typeof resetAt !== "number" || !Number.isFinite(resetAt) || resetAt <= 0)
            return qsTr("reset time unavailable");
        let seconds = Math.max(0, Math.floor(resetAt - service.now / 1000));
        if (seconds <= 30)
            return qsTr("resets now");
        const days = Math.floor(seconds / 86400);
        seconds %= 86400;
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (days > 0)
            return qsTr("resets in %1d %2h").arg(days).arg(hours);
        if (hours > 0)
            return qsTr("resets in %1h %2m").arg(hours).arg(minutes);
        return qsTr("resets in %1m").arg(Math.max(1, minutes));
    }

    function exactReset(resetAt: var): string {
        if (typeof resetAt !== "number" || !Number.isFinite(resetAt) || resetAt <= 0)
            return "";
        return Qt.formatDateTime(new Date(resetAt * 1000), "MMM d · HH:mm");
    }

    function updatedLabel(): string {
        const timestamp = service.mostRecentUpdatedAt;
        if (timestamp <= 0)
            return service.codex.loading ? qsTr("syncing usage") : qsTr("waiting for usage data");
        const seconds = Math.max(0, Math.floor((service.now - timestamp) / 1000));
        if (seconds < 45)
            return qsTr("updated just now");
        if (seconds < 3600)
            return qsTr("updated %1m ago").arg(Math.floor(seconds / 60));
        return qsTr("updated %1h ago").arg(Math.floor(seconds / 3600));
    }

    ColumnLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.margins: root.contentPadding
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "neurology"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.small
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("AI Usage")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Live account limits")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }

            RowLayout {
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    visible: root.service.codex.loading
                    text: "sync"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: root.updatedLabel()
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ProviderCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                provider: root.service.codex
                title: "CODEX"
                icon: "terminal"
                accent: Colours.palette.m3primary
                waitingHint: qsTr("Sign in with `codex login`")
            }

            ProviderCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                provider: root.service.antigravity
                title: "ANTIGRAVITY"
                icon: "auto_awesome"
                accent: Colours.palette.m3tertiary
                waitingHint: qsTr("Open `agy` once to sync usage")
            }
        }
    }

    component ProviderCard: StyledClippingRect {
        id: card

        required property var provider
        required property string title
        required property string icon
        required property color accent
        required property string waitingHint

        implicitHeight: providerLayout.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer

        StyledRect {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: card.accent
        }

        ColumnLayout {
            id: providerLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledRect {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: Tokens.rounding.full
                    color: Qt.alpha(card.accent, 0.16)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: card.icon
                        color: card.accent
                        fontStyle: Tokens.font.icon.small
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: card.title
                        color: card.accent
                        font: Tokens.font.label.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.formatPlan(card.provider.plan)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                StyledRect {
                    visible: card.provider.stale
                    Layout.preferredWidth: staleText.implicitWidth + Tokens.padding.small
                    Layout.preferredHeight: staleText.implicitHeight + 4
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3surfaceContainerHighest

                    StyledText {
                        id: staleText

                        anchors.centerIn: parent
                        text: qsTr("stale")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }
            }

            Repeater {
                model: card.provider.quotas

                ColumnLayout {
                    id: quotaRow

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.extraSmall
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: quotaRow.modelData.label
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: qsTr("%1% left").arg(root.formatPercent(quotaRow.modelData.remainingPercent))
                            color: card.accent
                            font: Tokens.font.label.medium
                        }
                    }

                    StyledProgressBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        value: quotaRow.modelData.remainingPercent / 100
                        fgColour: card.accent
                        bgColour: Qt.alpha(card.accent, 0.18)
                        wavy: true
                        waveAmplitude: 0.35
                        waveFrequency: 5
                        waveDuration: 2600
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: root.resetCountdown(quotaRow.modelData.resetAt)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            visible: text.length > 0
                            text: root.exactReset(quotaRow.modelData.resetAt)
                            color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.78)
                            font: Tokens.font.label.small
                        }
                    }
                }
            }

            RowLayout {
                visible: card.provider.quotas.length === 0
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                spacing: Tokens.spacing.small

                StyledProgressBar {
                    visible: card.provider.loading
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 4
                    indeterminate: true
                    fgColour: card.accent
                    bgColour: Qt.alpha(card.accent, 0.16)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: card.provider.loading ? qsTr("Fetching quota…") : (card.provider.error || qsTr("Quota unavailable"))
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !card.provider.loading
                        text: card.waitingHint
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }
            }

            StyledText {
                visible: card.provider.quotas.length > 0 && card.provider.error.length > 0
                Layout.fillWidth: true
                text: card.provider.error
                color: Colours.palette.m3error
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
