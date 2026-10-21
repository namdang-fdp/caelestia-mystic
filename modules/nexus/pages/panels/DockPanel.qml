pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> hideItems: [
        MenuItem {
            icon: "visibility"
            text: qsTr("Always show")
        },
        MenuItem {
            icon: "auto_awesome"
            text: qsTr("Hide when covered")
        },
        MenuItem {
            icon: "visibility_off"
            text: qsTr("Auto hide")
        }
    ]

    readonly property list<MenuItem> badgeItems: [
        MenuItem {
            icon: "counter_1"
            text: qsTr("Count")
        },
        MenuItem {
            icon: "circle"
            text: qsTr("Dot")
        }
    ]

    title: qsTr("Dock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Behaviour
        SectionHeader {
            first: true
            text: qsTr("Behaviour")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            subtext: qsTr("Show the dock at the bottom of every screen")
            checked: DockConfig.enabled
            onToggled: DockConfig.set("enabled", checked)
        }

        SelectRow {
            label: qsTr("Visibility")
            subtext: qsTr("Hidden docks reveal when the cursor touches the bottom edge")
            menuItems: root.hideItems
            active: root.hideItems[DockConfig.hideModes.indexOf(DockConfig.hideMode)] ?? root.hideItems[1]
            onSelected: item => DockConfig.set("hideMode", DockConfig.hideModes[root.hideItems.indexOf(item)])
        }

        ToggleRow {
            text: qsTr("Show running apps")
            subtext: qsTr("Open apps that are not pinned appear after a divider")
            checked: DockConfig.showRunning
            onToggled: DockConfig.set("showRunning", checked)
        }

        ToggleRow {
            last: true
            text: qsTr("Bounce on launch")
            subtext: qsTr("Bounce icons while apps open or need attention")
            checked: DockConfig.bounce
            onToggled: DockConfig.set("bounce", checked)
        }

        // Size
        SectionHeader {
            text: qsTr("Size")
        }

        StepperRow {
            first: true
            label: qsTr("Icon size")
            subtext: qsTr("Resting size of dock icons in pixels")
            value: DockConfig.iconSize
            from: 32
            to: 96
            stepSize: 4
            onMoved: v => DockConfig.set("iconSize", v)
        }

        ToggleRow {
            text: qsTr("Magnification")
            subtext: qsTr("Enlarge icons under the cursor")
            checked: DockConfig.magnify
            onToggled: DockConfig.set("magnify", checked)
        }

        SliderRow {
            enabled: DockConfig.magnify
            opacity: enabled ? 1 : 0.5
            icon: "zoom_in"
            label: qsTr("Magnification amount")
            valueLabel: `${Math.round(DockConfig.magnification * 100)}%`
            value: (DockConfig.magnification - 1) / 1.2
            onMoved: v => DockConfig.set("magnification", Math.round((1 + v * 1.2) * 20) / 20)
        }

        StepperRow {
            last: true
            label: qsTr("Bottom margin")
            subtext: qsTr("Gap between the dock and the screen edge")
            value: DockConfig.bottomMargin
            from: 0
            to: 48
            stepSize: 2
            onMoved: v => DockConfig.set("bottomMargin", v)
        }

        // Indicators
        SectionHeader {
            text: qsTr("Indicators")
        }

        ToggleRow {
            first: true
            text: qsTr("Running indicators")
            subtext: qsTr("Dot under apps with open windows")
            checked: DockConfig.showIndicators
            onToggled: DockConfig.set("showIndicators", checked)
        }

        ToggleRow {
            text: qsTr("App names")
            subtext: qsTr("Show the app name above the hovered icon")
            checked: DockConfig.showLabels
            onToggled: DockConfig.set("showLabels", checked)
        }

        ToggleRow {
            text: qsTr("Notification badges")
            subtext: qsTr("Unread notifications from the app")
            checked: DockConfig.showBadges
            onToggled: DockConfig.set("showBadges", checked)
        }

        SelectRow {
            last: true
            enabled: DockConfig.showBadges
            opacity: enabled ? 1 : 0.5
            label: qsTr("Badge style")
            menuItems: root.badgeItems
            active: DockConfig.badgeStyle === "dot" ? root.badgeItems[1] : root.badgeItems[0]
            onSelected: item => DockConfig.set("badgeStyle", item === root.badgeItems[1] ? "dot" : "count")
        }

        // Pinned apps
        SectionHeader {
            text: qsTr("Pinned apps")
        }

        Repeater {
            id: pinnedList

            model: ScriptModel {
                values: DockConfig.pinnedApps
            }

            ConnectedRect {
                id: pinnedItem

                required property string modelData
                required property int index
                readonly property DesktopEntry entry: DesktopEntries.byId(modelData)

                Layout.fillWidth: true
                first: index === 0
                implicitHeight: pinnedRow.implicitHeight + pinnedRow.anchors.margins * 2

                RowLayout {
                    id: pinnedRow

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    IconImage {
                        asynchronous: true
                        implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.8)
                        source: Quickshell.iconPath(pinnedItem.entry?.icon ?? "", "image-missing")
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: pinnedItem.entry?.name ?? pinnedItem.modelData
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: pinnedItem.entry ? pinnedItem.modelData : qsTr("App not installed")
                            color: pinnedItem.entry ? Colours.palette.m3outline : Colours.palette.m3error
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "arrow_upward"
                        disabled: pinnedItem.index === 0
                        onClicked: DockConfig.movePinned(pinnedItem.modelData, -1)
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "arrow_downward"
                        disabled: pinnedItem.index === pinnedList.count - 1
                        onClicked: DockConfig.movePinned(pinnedItem.modelData, 1)
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "close"
                        onClicked: DockConfig.unpin(pinnedItem.modelData)
                    }
                }
            }
        }

        AddAppRow {
            first: pinnedList.count === 0
            last: true
            icon: "add"
            label: qsTr("Add app")
            status: qsTr("Pin an installed app to the dock")
        }
    }

    component AddAppRow: PopupRow {
        id: row

        readonly property int popupHeight: root.flickable.height - y + root.flickable.contentY - Tokens.padding.large - Tokens.padding.extraExtraLarge

        keepPopupAsChild: {
            if (root.nState.animatingContainer || root.opacity < 1)
                return true;

            let p = root.parent;
            while (p && p.objectName !== "PageContainer")
                p = p.parent;
            return p?.opacity < 1;
        }
        popup.topMovement: Math.max(Tokens.sizes.nexus.minPopupHeight - popupHeight, Tokens.padding.large)

        Loader {
            anchors.centerIn: parent
            active: row.popup.animDriver > 0

            sourceComponent: VerticalFadeListView {
                id: list

                implicitWidth: Tokens.sizes.nexus.popupWidth
                implicitHeight: CUtils.clamp(row.popupHeight, Tokens.sizes.nexus.minPopupHeight, Tokens.sizes.nexus.maxPopupHeight)

                model: [...DesktopEntries.applications.values].filter(a => !a.noDisplay && !DockConfig.pinnedApps.includes(a.id)).sort((a, b) => a.name.localeCompare(b.name))

                delegate: StateLayer {
                    id: appItem

                    required property DesktopEntry modelData

                    anchors.fill: undefined
                    anchors.left: list.contentItem.left
                    anchors.right: list.contentItem.right
                    implicitHeight: itemLayout.implicitHeight + itemLayout.anchors.margins * 2
                    radius: Tokens.rounding.small

                    onClicked: {
                        row.popup.open = false;
                        DockConfig.pin(modelData.id);
                    }

                    RowLayout {
                        id: itemLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        IconImage {
                            asynchronous: true
                            implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.8)
                            source: Quickshell.iconPath(appItem.modelData.icon, "image-missing")
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: appItem.modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
