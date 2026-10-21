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
    }
}
