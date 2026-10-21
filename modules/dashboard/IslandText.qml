import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledText {
    // Use proportional UI type locally, retaining the shell's size/weight scale.
    property font islandFont: Tokens.font.body.small
    color: IslandTheme.palette.m3onSurface
    font.family: IslandTheme.fontFamily
    font.pixelSize: islandFont.pixelSize
    font.weight: islandFont.weight
    font.italic: islandFont.italic
    font.letterSpacing: 0
}
