pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// State of the fullscreen music show and the floating desktop lyrics.
Singleton {
    id: root
    property alias show: props.show
    property alias desktopLyrics: props.desktopLyrics
    property alias theme: props.theme

    function toggleShow(): void { show = !show; }
    function toggleLyrics(): void { desktopLyrics = !desktopLyrics; }
    function nextTheme(): void { theme = (theme + 1) % 5; }

    PersistentProperties {
        id: props
        reloadableId: "musicShow"
        property bool show
        property bool desktopLyrics
        property int theme
    }
    IpcHandler {
        target: "musicShow"
        function toggle(): void { root.toggleShow(); }
        function lyrics(): void { root.toggleLyrics(); }
        function theme(index: int): void { root.theme = Math.max(0, index); }
    }
}
