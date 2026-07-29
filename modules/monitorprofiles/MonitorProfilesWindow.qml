pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

StyledWindow {
    id: root

    required property LazyLoader loader
    required property var controller
    required property var snapshots

    readonly property var profiles: [{
            id: "auto",
            title: qsTr("Auto"),
            subtitle: qsTr("Follow the connected display topology"),
            icon: "auto_awesome"
        }, {
            id: "home-dual",
            title: qsTr("Home Dual"),
            subtitle: qsTr("External left · Laptop right"),
            icon: "display_settings"
        }, {
            id: "laptop-only",
            title: qsTr("Laptop Only"),
            subtitle: qsTr("Use the built-in display at 0x0"),
            icon: "laptop"
        }, {
            id: "external-only",
            title: qsTr("External Only"),
            subtitle: qsTr("Use HDMI at 0x0"),
            icon: "desktop_windows"
        }]

    property int selectedIndex: Math.max(0, profiles.findIndex(profile => profile.id === controller.selectedProfile))
    readonly property string selectedProfile: profiles[selectedIndex]?.id ?? "auto"
    readonly property string previewProfile: selectedProfile === "auto" ? resolvedAutoProfile() : selectedProfile

    function monitorNamed(name: string): var {
        return snapshots.find(snapshot => snapshot.name === name) ?? null;
    }

    function resolvedAutoProfile(): string {
        if (monitorNamed(controller.externalConnector) && monitorNamed(controller.laptopConnector))
            return "home-dual";
        return "laptop-only";
    }

    function profileAvailable(profile: string): bool {
        if (profile === "auto")
            return !!monitorNamed(controller.laptopConnector);
        if (profile === "home-dual")
            return !!monitorNamed(controller.externalConnector) && !!monitorNamed(controller.laptopConnector);
        if (profile === "laptop-only")
            return !!monitorNamed(controller.laptopConnector);
        if (profile === "external-only")
            return !!monitorNamed(controller.externalConnector);
        return false;
    }

    function selectRelative(delta: int): void {
        selectedIndex = (selectedIndex + delta + profiles.length) % profiles.length;
    }

    function applySelected(): void {
        if (!profileAvailable(selectedProfile)) {
            controller.showFailure(qsTr("%1 is unavailable for the current topology").arg(profiles[selectedIndex].title));
            return;
        }
        if (controller.requestApply(selectedProfile, "manual", true))
            close();
    }

    function close(): void {
        if (!loader.closing)
            closeAnimation.start();
    }

    function formatRefresh(value: real): string {
        if (!value || value <= 0)
            return qsTr("Unknown refresh");
        const rounded = Math.abs(value - Math.round(value)) < 0.01 ? Math.round(value).toString() : value.toFixed(2);
        return qsTr("%1 Hz").arg(rounded);
    }

    function formatScale(value: real): string {
        const scale = Number(value);
        return isFinite(scale) && scale > 0 ? scale.toFixed(scale % 1 === 0 ? 0 : 2) : "1";
    }

    name: "monitor-profiles"
    color: "transparent"
    surfaceFormat.opaque: false

    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: loader.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    mask: loader.closing ? emptyRegion : null

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Region {
        id: emptyRegion
    }

    SequentialAnimation {
        id: closeAnimation

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        ParallelAnimation {
            Anim {
                target: panel
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            Anim {
                target: panel
                property: "scale"
                to: 0.96
                type: Anim.StandardLarge
            }
            Anim {
                target: scrim
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    FocusScope {
        id: focusScope

        anchors.fill: parent
        focus: true

        Component.onCompleted: {
            root.loader.closing = false;
            forceActiveFocus();
            panel.opacity = 1;
            panel.scale = 1;
            scrim.opacity = 1;
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close();
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.selectRelative(-1);
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.selectRelative(1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.applySelected();
            } else {
                return;
            }
            event.accepted = true;
        }

        StyledRect {
            id: scrim

            anchors.fill: parent
            opacity: 0
            color: Qt.alpha(Colours.palette.m3scrim, 0.76)

            Behavior on opacity {
                Anim {
                    type: Anim.StandardLarge
                }
            }

            StateLayer {
                color: "transparent"
                onClicked: root.close()
            }
        }

        StyledRect {
            id: panel

            anchors.centerIn: parent
            width: Math.min(940, root.width - Tokens.padding.extraLarge * 2)
            height: Math.min(720, root.height - Tokens.padding.extraLarge * 2)
            opacity: 0
            scale: 0.96
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surface
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.48)

            Behavior on opacity {
                Anim {
                    type: Anim.StandardLarge
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.StandardLarge
                }
            }

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                opacity: parent.opacity
                z: -1
                level: 5
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.large

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: implicitHeight
                        implicitHeight: titleIcon.implicitHeight + Tokens.padding.large
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primaryContainer

                        MaterialIcon {
                            id: titleIcon

                            anchors.centerIn: parent
                            text: "display_settings"
                            fill: 1
                            color: Colours.palette.m3onPrimaryContainer
                            fontStyle: Tokens.font.icon.large
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: qsTr("Smart Monitor Profiles")
                            font: Tokens.font.body.builders.large.size(26).weight(Font.DemiBold).build()
                        }

                        StyledText {
                            text: qsTr("%1 mode · %2 active")
                                .arg(root.controller.profileMode === "auto" ? qsTr("Auto") : qsTr("Manual"))
                                .arg(root.controller.profileLabel(root.controller.lastAppliedProfile || root.previewProfile))
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.medium
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.width >= 850
                        text: qsTr("↑/↓ or j/k · Enter apply · Esc close")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }

                    IconButton {
                        implicitWidth: implicitHeight
                        implicitHeight: 42
                        icon: "close"
                        type: IconButton.Tonal
                        onClicked: root.close()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.large

                    ColumnLayout {
                        Layout.preferredWidth: 320
                        Layout.fillHeight: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.leftMargin: Tokens.padding.small
                            Layout.bottomMargin: Tokens.padding.extraSmall
                            text: qsTr("PROFILE")
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        }

                        Repeater {
                            model: root.profiles

                            StyledRect {
                                id: profileCard

                                required property int index
                                required property var modelData

                                readonly property bool selected: index === root.selectedIndex
                                readonly property bool available: root.profileAvailable(modelData.id)

                                Layout.fillWidth: true
                                implicitHeight: 82
                                radius: Tokens.rounding.largeIncreased
                                color: selected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerLow
                                border.width: selected ? 1 : 0
                                border.color: Qt.alpha(Colours.palette.m3primary, 0.55)
                                opacity: available ? 1 : 0.55

                                StateLayer {
                                    radius: parent.radius
                                    onClicked: root.selectedIndex = profileCard.index
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.medium
                                    spacing: Tokens.spacing.medium

                                    StyledRect {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 44
                                        implicitHeight: 44
                                        radius: Tokens.rounding.full
                                        color: profileCard.selected ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: profileCard.modelData.icon
                                            fill: profileCard.selected ? 1 : 0
                                            color: profileCard.selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                            fontStyle: Tokens.font.icon.medium
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: profileCard.modelData.title
                                            color: profileCard.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: profileCard.available ? profileCard.modelData.subtitle : qsTr("Not available")
                                            color: profileCard.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                            opacity: 0.78
                                            elide: Text.ElideRight
                                            font: Tokens.font.body.small
                                        }
                                    }

                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: profileCard.selected
                                        text: "check_circle"
                                        fill: 1
                                        color: Colours.palette.m3primary
                                        fontStyle: Tokens.font.icon.medium
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Tokens.spacing.medium

                        StyledRect {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 210
                            radius: Tokens.rounding.extraLarge
                            color: Colours.tPalette.m3surfaceContainerLow

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.padding.large
                                spacing: Tokens.spacing.medium

                                RowLayout {
                                    Layout.fillWidth: true

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Selected layout")
                                        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                                    }

                                    StyledRect {
                                        implicitWidth: previewLabel.implicitWidth + Tokens.padding.medium * 2
                                        implicitHeight: previewLabel.implicitHeight + Tokens.padding.small
                                        radius: Tokens.rounding.full
                                        color: Colours.palette.m3primaryContainer

                                        StyledText {
                                            id: previewLabel

                                            anchors.centerIn: parent
                                            text: root.controller.profileLabel(root.selectedProfile)
                                            color: Colours.palette.m3onPrimaryContainer
                                            font: Tokens.font.body.small
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Tokens.spacing.medium

                                        StyledRect {
                                            visible: root.previewProfile === "home-dual" || root.previewProfile === "external-only"
                                            width: 210
                                            height: 118
                                            radius: Tokens.rounding.medium
                                            color: Colours.palette.m3primary
                                            border.width: 3
                                            border.color: Colours.palette.m3onPrimary

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 2

                                                MaterialIcon {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: "desktop_windows"
                                                    color: Colours.palette.m3onPrimary
                                                    fontStyle: Tokens.font.icon.large
                                                }

                                                StyledText {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: root.controller.externalConnector
                                                    color: Colours.palette.m3onPrimary
                                                    font: Tokens.font.body.small
                                                }
                                            }
                                        }

                                        StyledRect {
                                            visible: root.previewProfile === "home-dual" || root.previewProfile === "laptop-only"
                                            width: 188
                                            height: 118
                                            radius: Tokens.rounding.medium
                                            color: Colours.palette.m3secondaryContainer
                                            border.width: 3
                                            border.color: Colours.palette.m3onSecondaryContainer

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 2

                                                MaterialIcon {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: "laptop"
                                                    color: Colours.palette.m3onSecondaryContainer
                                                    fontStyle: Tokens.font.icon.large
                                                }

                                                StyledText {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: root.controller.laptopConnector
                                                    color: Colours.palette.m3onSecondaryContainer
                                                    font: Tokens.font.body.small
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.leftMargin: Tokens.padding.small
                            text: qsTr("CONNECTED MONITORS")
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: root.snapshots

                                StyledRect {
                                    id: monitorCard

                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: 92
                                    radius: Tokens.rounding.largeIncreased
                                    color: Colours.tPalette.m3surfaceContainer
                                    border.width: 1
                                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Tokens.padding.medium
                                        spacing: Tokens.spacing.medium

                                        StyledRect {
                                            Layout.alignment: Qt.AlignVCenter
                                            implicitWidth: 46
                                            implicitHeight: 46
                                            radius: Tokens.rounding.full
                                            color: monitorCard.modelData.enabled ? Colours.palette.m3tertiaryContainer : Colours.tPalette.m3surfaceContainerHighest

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: monitorCard.modelData.name === root.controller.laptopConnector ? "laptop" : "monitor"
                                                fill: monitorCard.modelData.enabled ? 1 : 0
                                                color: monitorCard.modelData.enabled ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3outline
                                                fontStyle: Tokens.font.icon.medium
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            RowLayout {
                                                Layout.fillWidth: true

                                                StyledText {
                                                    text: monitorCard.modelData.name
                                                    font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                                                }

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: monitorCard.modelData.description
                                                    color: Colours.palette.m3onSurfaceVariant
                                                    elide: Text.ElideRight
                                                    font: Tokens.font.body.small
                                                }

                                                StyledText {
                                                    text: monitorCard.modelData.enabled ? qsTr("Active") : qsTr("Disabled")
                                                    color: monitorCard.modelData.enabled ? Colours.palette.m3primary : Colours.palette.m3outline
                                                    font: Tokens.font.body.small
                                                }
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: qsTr("%1×%2 · %3 · %4x%5 · Scale %6")
                                                    .arg(monitorCard.modelData.width)
                                                    .arg(monitorCard.modelData.height)
                                                    .arg(root.formatRefresh(monitorCard.modelData.refreshRate))
                                                    .arg(monitorCard.modelData.x)
                                                    .arg(monitorCard.modelData.y)
                                                    .arg(root.formatScale(monitorCard.modelData.scale))
                                                color: Colours.palette.m3onSurfaceVariant
                                                font: Tokens.font.body.small
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: root.controller.applying ? qsTr("Applying monitor profile…") : qsTr("Changes are applied live through Hyprland")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }

                    TextButton {
                        implicitWidth: 94
                        implicitHeight: 42
                        text: qsTr("Close")
                        type: TextButton.Tonal
                        onClicked: root.close()
                    }

                    IconTextButton {
                        implicitWidth: 118
                        implicitHeight: 42
                        icon: "check"
                        text: qsTr("Apply")
                        disabled: root.controller.applying || !root.profileAvailable(root.selectedProfile)
                        onClicked: root.applySelected()
                    }
                }
            }
        }
    }
}
