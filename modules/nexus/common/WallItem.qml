pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    readonly property bool imageError: img.status === Image.Error

    property alias source: img.source
    property alias text: label.text
    property alias radius: imgWrapper.radius
    property alias imgHeight: imgWrapper.implicitHeight
    property bool fillLabel: true
    property bool selected

    signal clicked

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: selected ? qsTr("Selected wallpaper") : qsTr("Preview wallpaper")
    Accessible.onPressAction: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.largeIncreased
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Colours.palette.m3primary
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.small

        StyledClippingRect {
            id: imgWrapper

            Layout.fillWidth: true
            implicitHeight: width
            radius: Tokens.rounding.largeIncreased
            color: Colours.tPalette.m3surfaceContainer

            Loader {
                anchors.centerIn: parent

                opacity: img.status === Image.Ready ? 0 : 1
                active: opacity > 0

                sourceComponent: StyledRect {
                    implicitWidth: loadingIndicator.implicitSize + Tokens.padding.large * 2
                    implicitHeight: loadingIndicator.implicitSize + Tokens.padding.large * 2

                    color: Colours.palette.m3primaryContainer
                    radius: Tokens.rounding.full

                    LoadingIndicator {
                        id: loadingIndicator

                        anchors.centerIn: parent
                        containsIcon: true
                        animated: !root.imageError
                        visible: !root.imageError
                        implicitSize: Math.min(imgWrapper.width, imgWrapper.height) * 0.3
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: root.imageError
                        text: "broken_image"
                        color: Colours.palette.m3onErrorContainer
                        fontStyle: Tokens.font.icon.extraLarge
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Image {
                id: img

                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: {
                    const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                    return Qt.size(width * dpr, height * dpr);
                }
                retainWhileLoading: true
                opacity: status === Image.Ready ? 1 : 0

                onStatusChanged: {
                    if (status === Image.Error && source)
                        console.warn(`Wallpaper thumbnail failed to decode: ${source}`);
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }

            StyledRect {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Tokens.padding.small
                visible: root.selected
                color: Colours.palette.m3primaryContainer
                radius: height / 2
                implicitWidth: selectedIcon.implicitWidth + Tokens.padding.small * 2
                implicitHeight: implicitWidth

                MaterialIcon {
                    id: selectedIcon
                    anchors.centerIn: parent
                    text: "check"
                    color: Colours.palette.m3onPrimaryContainer
                    fontStyle: Tokens.font.icon.small
                }
            }
        }

        StyledText {
            id: label

            Layout.bottomMargin: Tokens.padding.small
            Layout.fillWidth: true
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.builders.small.weight(Font.Medium).build()
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    StateLayer {
        anchors.bottomMargin: root.fillLabel ? 0 : layout.implicitHeight - imgWrapper.implicitHeight
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }
}
