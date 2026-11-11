import QtQuick

// A small static mascot drawn from rectangles. The face follows the mood:
// "working" is alert, "waiting" is surprised, "tired" has sleepy eyes.
Item {
    id: root
    property string mood: "idle"
    property int kind: 0
    readonly property var palettes: [["#f08a33", "#d96f1d", "#f7e4c6"], ["#5ea5ff", "#3d84e0", "#e6f0ff"], ["#ff8fb3", "#e66b94", "#fff0f5"], ["#6fd08c", "#4fb06c", "#eefaf0"]]
    implicitWidth: 92
    implicitHeight: 88
    readonly property color fur: palettes[kind % 4][0]
    readonly property color earColour: palettes[kind % 4][1]
    readonly property color belly: palettes[kind % 4][2]
    readonly property color ink: "#2b1708"

    Rectangle { x: 10; y: 4; width: 24; height: 24; radius: 12; color: root.earColour }
    Rectangle { x: 58; y: 4; width: 24; height: 24; radius: 12; color: root.earColour }
    Rectangle { x: 4; y: 14; width: 84; height: 72; radius: 36; color: root.fur }
    Rectangle { x: 24; y: 50; width: 44; height: 34; radius: 17; color: root.belly }
    // Cheeks
    Rectangle { x: 14; y: 46; width: 11; height: 7; radius: 4; color: "#ff9a8a"; opacity: .55 }
    Rectangle { x: 67; y: 46; width: 11; height: 7; radius: 4; color: "#ff9a8a"; opacity: .55 }
    // Eyes
    Rectangle { x: 29; y: root.mood === "tired" ? 41 : 36; width: 9; height: root.mood === "tired" ? 3 : root.mood === "waiting" ? 13 : 11; radius: 4.5; color: root.ink }
    Rectangle { x: 54; y: root.mood === "tired" ? 41 : 36; width: 9; height: root.mood === "tired" ? 3 : root.mood === "waiting" ? 13 : 11; radius: 4.5; color: root.ink }
    // Mouth
    Rectangle {
        x: root.mood === "waiting" ? 40 : 37
        y: root.mood === "waiting" ? 52 : 50
        width: root.mood === "waiting" ? 12 : 18
        height: root.mood === "waiting" ? 12 : root.mood === "tired" ? 3 : 8
        radius: root.mood === "tired" ? 2 : height / 2
        color: root.mood === "tired" ? root.ink : "#8a2f12"
    }
}
