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
        readonly property color m3onSurfaceVariant: "#99ebebf5"
        readonly property color m3outline: "#4debebf5"
        readonly property color m3outlineVariant: "#3a3a3c"
        readonly property color m3primary: "#ffffff"
        readonly property color m3onPrimary: "#000000"
        readonly property color m3secondary: "#d9ffffff"
        readonly property color m3tertiary: "#0a84ff"
        readonly property color m3error: "#ff453a"
        // Island-specific roles shared by cards, switches and sliders.
        readonly property color accent: "#0a84ff"
        readonly property color card: "#1c1c1e"
        readonly property color cardHover: "#2c2c2e"
        readonly property color cardBorder: "#00ffffff"
        readonly property color chip: "#2c2c2e"
        readonly property color chipActive: "#0a84ff"
        readonly property color chipActiveText: "#ffffff"
        readonly property color track: "#3a3a3c"
        readonly property color trackFill: "#ffffff"
        readonly property color trackDisabled: "#48484a"
        readonly property color trackFillText: "#000000"
        readonly property color divider: "#38383a"
        readonly property color handle: "#48484a"
        readonly property color focus: "#0a84ff"
        readonly property color success: "#30d158"
        readonly property color successSoft: "#30d158"
        readonly property color warning: "#ff9f0a"
        readonly property color switchOff: "#39393d"
        readonly property color awake: "#64d2ff"
        // Apple system colours, used to give each feature its own tint.
        readonly property color blue: "#0a84ff"
        readonly property color green: "#30d158"
        readonly property color orange: "#ff9f0a"
        readonly property color yellow: "#ffd60a"
        readonly property color red: "#ff453a"
        readonly property color pink: "#ff375f"
        readonly property color purple: "#bf5af2"
        readonly property color indigo: "#5e5ce6"
        readonly property color teal: "#64d2ff"
        // The idle companion's eyes and their soft blue glow.
        readonly property color eyes: "#ffffff"
        readonly property color eyesGlow: "#78beff"
    }
}
