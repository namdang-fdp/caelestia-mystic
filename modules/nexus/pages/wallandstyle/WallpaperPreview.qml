pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    readonly property string displayedPath: selectedPath || Wallpapers.actualCurrent
    readonly property bool pending: selectedPath.length > 0 && selectedPath !== Wallpapers.actualCurrent
    property string selectedPath

    function apply(): void {
        if (!pending || previewImage.status !== Image.Ready || Wallpapers.previewLoading)
            return;
        if (Colours.scheme === "dynamic")
            Wallpapers.previewColourLock = true;
        Wallpapers.setWallpaper(selectedPath);
        cancel();
    }
    function cancel(): void {
        if (selectedPath && Wallpapers.previewPath === selectedPath && Wallpapers.showPreview)
            Wallpapers.stopPreview();
        selectedPath = "";
    }
    function select(path: string): void {
        if (!path)
            return;
        selectedPath = path;
        if (pending)
            Wallpapers.preview(path);
        else
            cancel();
    }

    Layout.fillWidth: true
    spacing: Tokens.spacing.small

    Component.onDestruction: cancel()
    onVisibleChanged: {
        if (!visible)
            cancel();
    }

    StyledClippingRect {
        Layout.fillWidth: true
        color: Colours.tPalette.m3surfaceContainer
        implicitHeight: Math.min(width * 0.45, 250)
        radius: Tokens.rounding.extraLarge

        Image {
            id: previewImage

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            retainWhileLoading: true
            source: root.displayedPath
            sourceSize: Qt.size(width, height)
        }
    }
    StyledText {
        Accessible.role: Accessible.StaticText
        Layout.fillWidth: true
        color: Colours.palette.m3onSurfaceVariant
        elide: Text.ElideMiddle
        font: Tokens.font.body.small
        text: {
            if (previewImage.status === Image.Error)
                return qsTr("Could not load this image. Choose another wallpaper.");
            if (previewImage.status === Image.Loading || (root.pending && Wallpapers.previewLoading))
                return qsTr("Loading preview…");
            return root.pending ? qsTr("Preview — %1").arg(root.displayedPath.split("/").pop()) : qsTr("Current wallpaper");
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            text: root.pending ? qsTr("Apply to keep it, or cancel to restore your wallpaper.") : qsTr("Select an image below to preview it on your desktop.")
            wrapMode: Text.WordWrap
        }
        AppearanceButton {
            disabled: !root.pending
            icon: "close"
            text: qsTr("Cancel")
            type: IconTextButton.Tonal

            onClicked: root.cancel()
        }
        AppearanceButton {
            disabled: !root.pending || previewImage.status !== Image.Ready || Wallpapers.previewLoading
            icon: "check"
            text: qsTr("Apply")

            onClicked: root.apply()
        }
    }
}
