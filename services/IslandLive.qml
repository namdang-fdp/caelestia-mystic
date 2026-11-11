pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.services
import "../modules/dashboard/helpers/LiveLogic.js" as Logic

// Small live activities for the island: microphone and camera in use, caps
// lock, finished downloads, copied text and network changes. Everything is
// event driven except caps lock (one tiny file read per second) and the
// camera check (one short process every few seconds).
Singleton {
    id: root

    readonly property string downloads: `${Quickshell.env("HOME")}/Downloads`

    // Privacy indicators
    readonly property bool micActive: Audio.streams.some(s => Logic.isAppRecording(s.properties))
    readonly property bool cameraStream: Pipewire.nodes.values.some(n => n.isStream && Logic.isCameraStream(n.properties))
    property bool cameraDevice
    readonly property bool cameraActive: cameraStream || cameraDevice

    property bool capsLock
    property bool capsReady

    signal downloaded(string name)
    signal copied
    signal network(string kind)
    signal caps(bool on)

    // Network
    readonly property string connectivity: ["unknown", "none", "portal", "limited", "full"][Networking.connectivity] ?? "unknown"
    property string lastConnectivity: "unknown"
    onConnectivityChanged: {
        const kind = Logic.networkChange(lastConnectivity, connectivity);
        if (connectivity !== "unknown") lastConnectivity = connectivity;
        if (kind) network(kind);
    }
    Component.onCompleted: lastConnectivity = connectivity

    // Finished downloads
    property double lastDownloadAt: NaN
    Process {
        running: true
        command: ["sh", "-c", "[ -d \"$1\" ] && exec inotifywait -m -q -e close_write -e moved_to --format '%f' \"$1\"; exit 0", "sh", root.downloads]
        stdout: SplitParser {
            onRead: line => {
                const name = Logic.downloadName(line);
                const now = Date.now();
                if (!name || !Logic.allowEvent(root.lastDownloadAt, now, 2000)) return;
                root.lastDownloadAt = now;
                root.downloaded(name);
            }
        }
    }

    // Copy feedback: the watcher prints a line per clipboard change and never
    // reads the content. The first line is the clipboard as it already was.
    property bool clipboardSeen
    property double lastCopyAt: NaN
    Process {
        running: true
        command: ["wl-paste", "--watch", "sh", "-c", "cat >/dev/null; echo copy"]
        stdout: SplitParser {
            onRead: () => {
                if (!root.clipboardSeen) { root.clipboardSeen = true; return; }
                const now = Date.now();
                if (!Logic.allowEvent(root.lastCopyAt, now, 600)) return;
                root.lastCopyAt = now;
                root.copied();
            }
        }
    }

    // Camera in use by a program that bypasses PipeWire.
    Process {
        id: cameraCheck
        command: ["sh", "-c", "for d in /dev/video*; do [ -e \"$d\" ] && fuser -s \"$d\" 2>/dev/null && { echo 1; exit 0; }; done; echo 0"]
        stdout: StdioCollector { onStreamFinished: root.cameraDevice = text.trim() === "1" }
    }
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!cameraCheck.running) cameraCheck.running = true }

    // Caps lock: keyboard LEDs in sysfs.
    property var ledPaths: []
    property var ledValues: ({})
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/leds/*capslock/brightness 2>/dev/null; exit 0"]
        stdout: StdioCollector { onStreamFinished: root.ledPaths = text.split("\n").filter(l => l.startsWith("/sys/")) }
    }
    Instantiator {
        id: leds
        model: root.ledPaths
        delegate: FileView {
            id: led
            required property string modelData
            path: modelData
            printErrors: false
            onLoaded: {
                root.ledValues[modelData] = text().trim();
                root.updateCaps();
            }
        }
    }
    function reloadLeds(): void {
        for (let i = 0; i < leds.count; i++) leds.objectAt(i)?.reload();
    }
    function updateCaps(): void {
        const on = Logic.capsOn(Object.values(ledValues));
        if (on === capsLock && capsReady) return;
        const first = !capsReady;
        capsLock = on;
        capsReady = true;
        if (!first) caps(on);
    }
    Timer {
        interval: 1000; repeat: true; running: root.ledPaths.length > 0
        onTriggered: root.reloadLeds()
    }
}
