pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services

ColumnLayout {
    Layout.fillWidth: true
    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true

        SearchBar {
            id: search

            Layout.fillWidth: true
            placeholderText: qsTr("Search themes and flavours")
        }
        IconButton {
            Accessible.name: qsTr("Refresh colour schemes")
            activeFocusOnTab: !disabled
            disabled: Schemes.catalogLoading || Appearance.applying
            icon: "refresh"
            type: IconButton.Tonal

            Keys.onReturnPressed: {
                if (!disabled)
                    Schemes.reloadCatalog();
            }
            Keys.onSpacePressed: {
                if (!disabled)
                    Schemes.reloadCatalog();
            }
            onClicked: Schemes.reloadCatalog()
        }
    }
    AppearanceButton {
        disabled: Appearance.applying
        icon: "shuffle"
        text: qsTr("Random theme")
        type: IconTextButton.Tonal

        onClicked: Appearance.apply(["-r"])
    }
    StyledText {
        Layout.fillWidth: true
        color: Schemes.catalogError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        text: Schemes.catalogLoading ? qsTr("Loading colour schemes…") : Schemes.catalogError
        visible: (Schemes.catalogLoading || Schemes.catalogError.length > 0)
        wrapMode: Text.WordWrap
    }
    GridLayout {
        Layout.fillWidth: true
        columnSpacing: Tokens.spacing.small
        columns: width < 560 ? 1 : 2
        rowSpacing: Tokens.spacing.small

        Repeater {
            id: schemeOptions

            model: Schemes.list.filter(s => `${s.name} ${s.flavour}`.toLowerCase().includes(search.text.trim().toLowerCase()))

            ColourOption {
                required property var modelData

                description: modelData.flavour
                enabled: !Appearance.applying
                icon: modelData.name === "dynamic" ? "wallpaper" : "palette"
                selected: Colours.scheme === modelData.name && Colours.flavour === modelData.flavour
                swatches: ["surface", "primary", "secondary", "tertiary", "onSurface"].map(k => `#${modelData.colours[k]}`)
                title: modelData.name === "dynamic" ? qsTr("Wallpaper colours") : modelData.name

                onClicked: Appearance.apply(["-n", modelData.name, "-f", modelData.flavour])
            }
        }
    }
    StyledText {
        Layout.fillWidth: true
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        text: qsTr("No colour schemes match your search")
        visible: schemeOptions.count === 0 && !Schemes.catalogLoading && !Schemes.catalogError
    }
}
