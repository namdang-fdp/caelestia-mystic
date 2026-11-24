import QtQuick

// A small static mascot drawn from rectangles. The face follows the mood:
// "working" is alert, "waiting" is surprised, "tired" has sleepy eyes.
Item {
    id: root
    property string mood: "idle"
    property int kind: 0
    // Grows accessories with the commit-streak level: a bow at 3, a crown at 5, sparkles at 8.
    property int level: 1
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
    // Eyes: round, wide when surprised, a flat line when tired, happy arcs at a party.
    readonly property bool flatEyes: mood === "tired"
    readonly property bool happyEyes: mood === "party"
    Rectangle { x: 29; y: root.flatEyes ? 41 : root.happyEyes ? 38 : root.mood === "sad" ? 38 : 36; width: 9; height: root.flatEyes ? 3 : root.happyEyes ? 5 : root.mood === "waiting" ? 13 : root.mood === "sad" ? 10 : 11; radius: root.happyEyes ? 2.5 : 4.5; color: root.ink; rotation: root.mood === "sad" ? -12 : 0 }
    Rectangle { x: 54; y: root.flatEyes ? 41 : root.happyEyes ? 38 : root.mood === "sad" ? 38 : 36; width: 9; height: root.flatEyes ? 3 : root.happyEyes ? 5 : root.mood === "waiting" ? 13 : root.mood === "sad" ? 10 : 11; radius: root.happyEyes ? 2.5 : 4.5; color: root.ink; rotation: root.mood === "sad" ? 12 : 0 }
    // Mouth: open when surprised or celebrating, a short frown when worried.
    Rectangle {
        x: root.mood === "waiting" ? 40 : root.mood === "party" ? 35 : root.mood === "sad" ? 39 : 37
        y: root.mood === "waiting" ? 52 : root.mood === "party" ? 50 : root.mood === "sad" ? 54 : 50
        width: root.mood === "waiting" ? 12 : root.mood === "party" ? 22 : root.mood === "sad" ? 14 : 18
        height: root.mood === "waiting" ? 12 : root.mood === "party" ? 13 : root.mood === "tired" ? 3 : root.mood === "sad" ? 3 : 8
        radius: root.mood === "tired" || root.mood === "sad" ? 2 : height / 2
        color: root.mood === "tired" || root.mood === "sad" ? root.ink : "#8a2f12"
    }
    // Confetti for a party: a few still squares.
    Repeater {
        model: root.mood === "party" ? [[4, 2, "#ffd60a", 20], [80, 6, "#30d158", -25], [88, 34, "#0a84ff", 40], [0, 40, "#ff375f", -15], [70, 0, "#bf5af2", 10]] : []
        Rectangle { required property var modelData; x: modelData[0]; y: modelData[1]; width: 7; height: 7; radius: 1.5; color: modelData[2]; rotation: modelData[3] }
    }
    // Level accessories.
    Rectangle { visible: root.level >= 3; x: 62; y: 12; width: 14; height: 9; radius: 4; color: "#ff375f"; rotation: -20 }
    Rectangle { visible: root.level >= 3; x: 74; y: 12; width: 14; height: 9; radius: 4; color: "#ff375f"; rotation: 20 }
    Rectangle { visible: root.level >= 3; x: 71; y: 13; width: 7; height: 7; radius: 3.5; color: "#c2185b" }
    Row {
        visible: root.level >= 5
        x: 31; y: -2; spacing: 2
        Repeater { model: 3; Rectangle { required property int index; width: 9; height: index === 1 ? 13 : 9; y: index === 1 ? -4 : 0; radius: 2; color: "#ffd60a" } }
    }
    Repeater {
        model: root.level >= 8 ? [[2, 22], [84, 20]] : []
        Rectangle { required property var modelData; x: modelData[0]; y: modelData[1]; width: 6; height: 6; radius: 1; color: "#fff3b0"; rotation: 45 }
    }
}
