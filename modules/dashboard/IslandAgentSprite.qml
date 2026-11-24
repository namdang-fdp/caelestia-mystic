pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root
    required property string agent
    required property string state
    property string travel
    property bool playing
    readonly property int row: travel === "right" ? 1 : travel === "left" ? 2
        : state === "waiting" ? 6 : state === "working" ? 7 : state === "done" ? 4 : 0
    readonly property int frames: row === 1 || row === 2 ? 8 : row === 4 ? 5 : 6
    readonly property bool loop: row !== 4
    readonly property real pixelScale: Math.min(width / 192, height / 208)
    property int frame
    clip: true

    onRowChanged: {
        frame = 0;
        if (ticker.running) ticker.restart();
    }

    Image {
        id: atlas
        source: "file://" + Paths.config + "/agent-pets/" + root.agent + ".webp"
        asynchronous: true
        visible: status === Image.Ready
        smooth: false
        width: 1536 * root.pixelScale
        height: 1872 * root.pixelScale
        x: (root.width - 192 * root.pixelScale) / 2 - 192 * root.pixelScale * root.frame
        y: (root.height - 208 * root.pixelScale) / 2 - 208 * root.pixelScale * root.row
    }
    Timer {
        id: ticker
        running: root.playing && atlas.status === Image.Ready && Tokens.anim.durations.scale > 0
            && (root.loop || root.frame < root.frames - 1)
        repeat: true
        interval: Math.max(16, (root.frame === root.frames - 1 ? 240 : root.row === 6 ? 150 : 120) * Tokens.anim.durations.scale)
        onTriggered: root.frame = (root.frame + 1) % root.frames
    }
    MaterialIcon {
        anchors.centerIn: parent
        visible: atlas.status !== Image.Ready
        text: root.agent === "codex" ? "smart_toy" : "asterisk"
        color: root.agent === "codex" ? IslandTheme.palette.blue : IslandTheme.palette.orange
    }
}
