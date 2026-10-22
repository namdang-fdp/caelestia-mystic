pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root
    property bool resizing: false
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "submap") root.resizing = event.data === "tide-resize";
        }
    }
    Process {
        running: true
        command: ["hyprctl", "submap"]
        stdout: StdioCollector { onStreamFinished: root.resizing = text.trim() === "tide-resize" }
    }
}
