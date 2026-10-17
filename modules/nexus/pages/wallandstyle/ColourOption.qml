pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    property string description
    property string icon: "palette"
    property bool selected
    property var swatches: []
    required property string title

    signal clicked

    Accessible.checkable: true
    Accessible.checked: selected
    Accessible.description: description
    Accessible.name: title
    Accessible.role: Accessible.RadioButton
    Layout.fillWidth: true
    activeFocusOnTab: true
    border.color: Colours.palette.m3primary
    border.width: root.activeFocus ? 2 : root.selected ? 1 : 0
    color: root.selected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
    implicitHeight: content.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large

    Accessible.onPressAction: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.margins: Tokens.padding.large
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
                text: root.icon
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font: Tokens.font.body.medium
                text: root.title
            }
            MaterialIcon {
                color: root.selected ? Colours.palette.m3primary : Colours.palette.m3outline
                fontStyle: Tokens.font.icon.small
                text: root.selected ? "check_circle" : "radio_button_unchecked"
            }
        }
        StyledText {
            Layout.fillWidth: true
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            text: root.description
            visible: root.description.length > 0
            wrapMode: Text.WordWrap
        }
        RowLayout {
            spacing: Tokens.spacing.small
            visible: root.swatches.length > 0

            Repeater {
                model: root.swatches

                Rectangle {
                    required property string modelData

                    border.color: Colours.palette.m3outlineVariant
                    border.width: 1
                    color: modelData
                    implicitHeight: implicitWidth
                    implicitWidth: Tokens.font.body.medium.pixelSize * 1.4
                    radius: height / 2
                }
            }
        }
    }
    StateLayer {
        disabled: !root.enabled

        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }
}
