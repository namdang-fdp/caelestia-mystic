pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// Whether the user has stepped away, for the island companion's doze. One
// shared monitor outside any window; created on first use.
Singleton {
    readonly property bool away: monitor.isIdle

    IdleMonitor {
        id: monitor
        timeout: 120
    }
}
