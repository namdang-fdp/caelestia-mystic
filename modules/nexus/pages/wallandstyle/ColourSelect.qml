pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.launcher.services

PageBase {
    id: root

    readonly property bool applying: Appearance.applying
    readonly property string errorMessage: Appearance.errorMessage
    property bool showVariants
    readonly property Connections themeSync: Connections {
        function onApplyingChanged(): void {
            if (!Appearance.applying)
                darkTheme.checked = Qt.binding(() => !Colours.currentLight);
        }

        target: Appearance
    }

    function apply(args: list<string>): void {
        Appearance.apply(args);
    }

    isSubPage: true
    title: qsTr("Colours & theme")

    Component.onCompleted: {
        Schemes.reload();
        Schemes.reloadCatalog();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: Tokens.spacing.small
        width: root.cappedWidth

        InfoRow {
            first: true
            icon: Colours.scheme === "dynamic" ? "wallpaper" : "palette"
            label: qsTr("Current theme")
            last: true
            subtext: Colours.scheme === "dynamic" ? qsTr("Colours follow your wallpaper") : qsTr("Applies to the desktop and themed apps")
            value: "%1 · %2".arg(Colours.scheme).arg(Colours.flavour)
        }
        ToggleRow {
            id: darkTheme

            checked: !Colours.currentLight
            enabled: !root.applying
            first: true
            last: true
            subtext: qsTr("Some preset themes support only dark or light mode")
            text: qsTr("Dark theme")

            onToggled: root.apply(["-m", checked ? "dark" : "light"])
        }
        StyledText {
            Accessible.role: Accessible.AlertMessage
            Layout.fillWidth: true
            color: root.errorMessage ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            text: root.applying ? qsTr("Applying colours…") : root.errorMessage
            visible: root.applying || root.errorMessage.length > 0
            wrapMode: Text.WordWrap
        }
        ButtonRow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            AppearanceButton {
                checked: !root.showVariants
                icon: "palette"
                text: qsTr("Colour schemes")
                type: IconTextButton.Tonal

                onClicked: root.showVariants = false
            }
            AppearanceButton {
                checked: root.showVariants
                icon: "auto_awesome"
                text: qsTr("Material 3 variants")
                type: IconTextButton.Tonal

                onClicked: root.showVariants = true
            }
        }
        ColourSchemes {
            visible: !root.showVariants
        }
        SectionHeader {
            text: qsTr("Material 3 variant")
            visible: root.showVariants
        }
        ToggleRow {
            checked: GlobalConfig.services.smartScheme
            first: true
            last: true
            subtext: qsTr("Choose the mode and variant automatically when applying a wallpaper")
            text: qsTr("Smart wallpaper colours")
            visible: root.showVariants

            onToggled: GlobalConfig.services.smartScheme = checked
        }
        StyledText {
            Layout.fillWidth: true
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            text: qsTr("Changes how colours are generated. Smart wallpaper colours can choose a different variant next time you change the wallpaper.")
            visible: root.showVariants
            wrapMode: Text.WordWrap
        }
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: Tokens.spacing.small
            columns: width < 560 ? 1 : 2
            rowSpacing: Tokens.spacing.small
            visible: root.showVariants

            Repeater {
                model: M3Variants.list

                ColourOption {
                    required property var modelData

                    description: modelData.description
                    enabled: !root.applying
                    icon: modelData.icon
                    selected: Colours.variant === modelData.variant
                    title: modelData.name

                    onClicked: root.apply(["-v", modelData.variant])
                }
            }
        }
    }
}
