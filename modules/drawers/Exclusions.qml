pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers

Scope {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    ExclusionZone {
        anchors.left: true
    }

    ExclusionZone {
        anchors.top: true
        // Reserve only the resting capsule. Expanded views overlay the desktop
        // without repeatedly resizing tiled windows during the morph.
        exclusiveZone: contentItem.Config.dashboard.enabled && !root.fullscreen ? 48 : 0
    }

    ExclusionZone {
        anchors.right: true
    }

    ExclusionZone {
        anchors.bottom: true
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: contentItem.Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
