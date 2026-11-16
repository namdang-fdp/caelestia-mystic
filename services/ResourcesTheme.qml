pragma Singleton

import QtQuick
import Quickshell

// Fixed, high-contrast palette for the resources drawer. Deliberately not derived
// from the wallpaper (Colours) so contrast never drifts.
Singleton {
    readonly property color surface: "#0A0A0A"
    readonly property color border: "#262626"
    readonly property color text: "#FFFFFF"
    readonly property color textDim: "#A1A1A1"
    readonly property color ok: "#3DD68C"
    readonly property color warm: "#F5A623"
    readonly property color hot: "#FF4D4F"
    readonly property int radius: 12
    readonly property string uiFont: "Geist"
    readonly property string numFont: "Maple Mono NF"
}
