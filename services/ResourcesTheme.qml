pragma Singleton

import QtQuick
import Quickshell

// Fixed dark macOS palette for the resources drawer. Deliberately not derived from the
// wallpaper (Colours) so contrast never drifts.
Singleton {
    // Surfaces
    readonly property color surface: "#0A0A0A"
    readonly property color card: "#1C1C1E"
    readonly property color track: "#2C2C2E"
    readonly property color hover: "#232325"
    readonly property color border: "#2C2C2E"
    readonly property color separator: "#38383A"

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
