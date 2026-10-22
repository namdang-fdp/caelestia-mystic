pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Variants {
    model: Screens.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        Exclusions {
            screen: scope.modelData
            fullscreen: content.hasFullscreen
        }

        ContentWindow {
            id: content

            screen: scope.modelData
        }
    }
}
