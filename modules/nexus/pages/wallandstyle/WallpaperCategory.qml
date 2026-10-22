pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: {
        const c = nState.selectedWallpaperCategory;
        return c.slice(0, 1).toUpperCase() + c.slice(1);
    }
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth

        spacing: Tokens.spacing.medium

        WallpaperPreview {
            id: preview
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(1, Math.min(Config.nexus.wallpapersPerRow, Math.floor(width / 180)))
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: Wallpapers.list.filter(w => Wallpapers.getCategoryFor(w) === root.nState.selectedWallpaperCategory).sort((a, b) => a.name.localeCompare(b.name))

                WallItem {
                    required property FileSystemEntry modelData

                    source: modelData.path
                    text: modelData.name
                    selected: preview.displayedPath === modelData.path
                    onClicked: preview.select(modelData.path)
                }
            }
        }
    }
}
