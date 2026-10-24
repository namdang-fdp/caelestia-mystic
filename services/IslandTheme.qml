pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string fontFamily: geist.status === FontLoader.Ready ? geist.name : "sans-serif"

    FontLoader {
        id: geist
        source: "../assets/fonts/geist/Geist-Variable.ttf"
    }

    // Island materials stay neutral when the wallpaper's accent colour changes.
    readonly property QtObject palette: QtObject {
        readonly property color m3surfaceContainer: "#0b0c0e"
        readonly property color m3surfaceContainerLow: "#15171a"
        readonly property color m3surfaceContainerHigh: "#24262a"
        readonly property color m3surfaceContainerHighest: "#303338"
        readonly property color m3onSurface: "#f5f5f7"
        readonly property color m3onSurfaceVariant: "#b7bac1"
        readonly property color m3outline: "#999da5"
        readonly property color m3outlineVariant: "#4b4e55"
        readonly property color m3primary: "#f5f5f7"
        readonly property color m3onPrimary: "#111214"
        readonly property color m3secondary: "#d3d6dc"
        readonly property color m3tertiary: "#b9d8ff"
        readonly property color m3error: "#ff817a"
        // Island-specific roles shared by cards, switches and sliders.
        readonly property color card: "#25282d"
        readonly property color cardHover: "#30343a"
        readonly property color cardBorder: "#10ffffff"
        readonly property color chip: "#33363d"
        readonly property color chipActive: "#23384d"
        readonly property color chipActiveText: "#a4d0ff"
        readonly property color track: "#303236"
        readonly property color trackFill: "#f3f3f5"
        readonly property color trackDisabled: "#777a80"
        readonly property color trackFillText: "#26282b"
        readonly property color divider: "#4a4d52"
        readonly property color handle: "#77797d"
        readonly property color focus: "#8daeff"
        readonly property color success: "#63d68b"
        readonly property color successSoft: "#8cdea9"
        readonly property color warning: "#f2c66d"
        readonly property color switchOff: "#60636a"
        readonly property color awake: "#cba6f7"
    }
}
