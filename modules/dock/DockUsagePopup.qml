pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Plan usage details opened from a dock usage tile
PopupWindow {
    id: root

    required property DockWindow dock
    property DockItem target

    readonly property bool loading: AiUsage.providers.some(p => p.loading)
    readonly property real updatedAt: Math.min(...AiUsage.providers.map(p => p.updatedAt || Infinity))

    function close(): void {
        visible = false;
    }

    anchor.item: target
    anchor.rect.x: target ? target.width / 2 : 0
    anchor.rect.y: target ? target.height - dock.pad - dock.iconSize - 10 : 0
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top

    implicitWidth: bg.implicitWidth
    implicitHeight: bg.implicitHeight
    color: "transparent"
    visible: false

    contentItem.Config.screen: dock.screen.name
    contentItem.Tokens.screen: dock.screen.name

    property double closedAt

    onVisibleChanged: {
        if (!visible)
            closedAt = Date.now();
        if (visible) {
            AiUsage.refresh(false);
            bg.opacity = 0;
            bg.scale = 0.94;
            openAnim.restart();
        }
    }

    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.close()
    }

    ParallelAnimation {
        id: openAnim

        Anim {
            target: bg
            property: "opacity"
            to: 1
            type: Anim.FastEffects
        }
        Anim {
            target: bg
            property: "scale"
            to: 1
            type: Anim.FastSpatial
        }
    }

    StyledRect {
        id: bg

        anchors.fill: parent
        implicitWidth: 300
        implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
        transformOrigin: Item.Bottom
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.6 : 0.45)

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            Repeater {
                model: AiUsage.providers

                ProviderSection {}
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.loading ? qsTr("Updating…") : AiUsage.updatedText(Number.isFinite(root.updatedAt) ? root.updatedAt : 0)
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    animate: true
                }

                IconButton {
                    id: refreshButton

                    type: IconButton.Text
                    icon: "refresh"
                    font: Tokens.font.icon.small
                    onClicked: AiUsage.refresh(true)

                    RotationAnimator {
                        target: refreshButton.label
                        running: root.loading
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                        onRunningChanged: if (!running) refreshButton.label.rotation = 0
                    }
                }
            }
        }
    }

    component ProviderSection: ColumnLayout {
        id: section

        required property AiUsage.Provider modelData
        required property int index

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.extraSmall
            visible: section.index > 0
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconImage {
                implicitSize: 20
                asynchronous: true
                mipmap: true
                source: Quickshell.iconPath(section.modelData.icon, "image-missing")
            }

            StyledText {
                text: section.modelData.name
                font: Tokens.font.title.small
            }

            StyledRect {
                visible: !!section.modelData.plan
                implicitWidth: planText.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: planText.implicitHeight + Tokens.padding.extraSmall * 2
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                StyledText {
                    id: planText

                    anchors.centerIn: parent
                    text: section.modelData.plan
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: section.modelData.limits

            LimitRow {}
        }

        StyledText {
            Layout.fillWidth: true
            visible: !!section.modelData.error
            text: section.modelData.error
            color: Colours.palette.m3error
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }
    }

    component LimitRow: ColumnLayout {
        id: limit

        required property var modelData
        readonly property real percent: modelData.usedPercent ?? 0

        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.extraSmall
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: limit.modelData.id === "session" ? qsTr("Session (5h)") : limit.modelData.label
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                text: `${Math.round(limit.percent)}%`
                color: AiUsage.severity(limit.percent) > 0 ? AiUsage.severityColour(limit.percent) : Colours.palette.m3onSurface
                font: Tokens.font.body.small
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 5
            radius: 3
            color: Qt.alpha(Colours.palette.m3onSurface, 0.12)

            Rectangle {
                implicitWidth: Math.max(parent.height, parent.width * Math.min(100, limit.percent) / 100)
                implicitHeight: parent.height
                radius: parent.radius
                visible: limit.percent > 0
                color: AiUsage.severityColour(limit.percent)

                Behavior on implicitWidth {
                    Anim {}
                }
            }
        }

        StyledText {
            visible: !!text
            text: AiUsage.resetText(limit.modelData.resetsAt ?? 0)
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}
