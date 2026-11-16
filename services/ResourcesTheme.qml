pragma Singleton

import QtQuick
import Quickshell

// Fixed dark macOS palette for the resources drawer. Deliberately not derived from the
// wallpaper (Colours) so contrast never drifts.
Singleton {
    // Surfaces
    readonly property color surface: "#0A0A0A"
    readonly property color card: Qt.rgba(1, 1, 1, 0.07)
    readonly property color track: Qt.rgba(1, 1, 1, 0.10)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.06)
    readonly property color border: Qt.rgba(1, 1, 1, 0.18)
    readonly property color separator: Qt.rgba(1, 1, 1, 0.10)

    // Glass panel: a translucent dark fill, a lit edge and a soft top highlight. Real backdrop blur
    // needs a compositor layer rule; without it the fill is opaque enough to keep text legible.
    readonly property real glassAlpha: 0.80
    readonly property color glass: Qt.rgba(16 / 255, 16 / 255, 22 / 255, glassAlpha)
    readonly property color glassHighlight: Qt.rgba(1, 1, 1, 0.07)

    // Labels (macOS secondary/tertiary are the same colour at lower alpha)
    readonly property color text: "#FFFFFF"
    readonly property color textDim: Qt.rgba(235 / 255, 235 / 255, 245 / 255, 0.6)
    readonly property color textTertiary: Qt.rgba(235 / 255, 235 / 255, 245 / 255, 0.3)

    // System colours
    readonly property color blue: "#0A84FF"
    readonly property color ok: "#30D158"
    readonly property color warm: "#FF9F0A"
    readonly property color hot: "#FF453A"
    readonly property color purple: "#BF5AF2"
    readonly property color teal: "#64D2FF"

    // Colour for a ResourceLogic.severity() level.
    function tone(level: string): color {
        return level === "hot" ? hot : level === "warm" ? warm : ok;
    }

    readonly property int radius: 12
    readonly property int radiusCard: 10
    readonly property int radiusControl: 6
    readonly property string uiFont: "Inter Variable"
    readonly property string numFont: "Inter Variable"
}
