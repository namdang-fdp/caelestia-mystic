pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Variants {
    model: DockConfig.enabled ? Screens.screens : []

    DockWindow {
        required property ShellScreen modelData

        screen: modelData
    }
}
