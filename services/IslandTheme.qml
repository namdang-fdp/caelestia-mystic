pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string fontFamily: geist.status === FontLoader.Ready ? geist.name : "sans-serif"

    FontLoader {
        id: geist
        source: "../assets/fonts/geist/Geist-Variable.ttf"
    }

    // iOS-style materials after Nusa: a pure black surface, translucent white
    // fills and type, and one blue accent. Colour is reserved for content.
    readonly property QtObject palette: QtObject {
        readonly property color m3surfaceContainer: "#000000"
        readonly property color m3surfaceContainerLow: "#0fffffff"
        readonly property color m3surfaceContainerHigh: "#1affffff"
        readonly property color m3surfaceContainerHighest: "#2bffffff"
        readonly property color m3onSurface: "#ffffff"
        readonly property color m3onSurfaceVariant: "#8cffffff"
        readonly property color m3outline: "#61ffffff"
        readonly property color m3outlineVariant: "#24ffffff"
        readonly property color m3primary: "#ffffff"
        readonly property color m3onPrimary: "#000000"
        readonly property color m3secondary: "#d9ffffff"
        readonly property color m3tertiary: "#5fb2ff"
        readonly property color m3error: "#ff5a6e"
        // Island-specific roles shared by cards, switches and sliders.
        readonly property color accent: "#2699ff"
        readonly property color card: "#1affffff"
        readonly property color cardHover: "#29ffffff"
        readonly property color cardBorder: "#00ffffff"
        readonly property color chip: "#1fffffff"
        readonly property color chipActive: "#2699ff"
        readonly property color chipActiveText: "#ffffff"
        readonly property color track: "#24ffffff"
        readonly property color trackFill: "#ffffff"
        readonly property color trackDisabled: "#59ffffff"
        readonly property color trackFillText: "#000000"
        readonly property color divider: "#24ffffff"
        readonly property color handle: "#4dffffff"
        readonly property color focus: "#2699ff"
        readonly property color success: "#33e07a"
        readonly property color successSoft: "#33e07a"
        readonly property color warning: "#ffd60a"
        readonly property color switchOff: "#38ffffff"
        readonly property color awake: "#5fb2ff"
        // The idle companion's eyes and their soft blue glow.
        readonly property color eyes: "#ffffff"
        readonly property color eyesGlow: "#78beff"
    }
}
