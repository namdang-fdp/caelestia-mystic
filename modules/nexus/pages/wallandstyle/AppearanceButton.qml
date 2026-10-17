import QtQuick
import Caelestia.Config
import qs.components.controls
import qs.services

IconTextButton {
    id: root

    Accessible.name: text
    Accessible.role: Accessible.Button
    activeFocusOnTab: !disabled
    border.color: Colours.palette.m3primary
    border.width: activeFocus ? 2 : 0

    Accessible.onPressAction: {
        if (!root.disabled)
            root.clicked();
    }
    Keys.onEnterPressed: {
        if (!root.disabled)
            root.clicked();
    }
    Keys.onReturnPressed: {
        if (!root.disabled)
            root.clicked();
    }
    Keys.onSpacePressed: {
        if (!root.disabled)
            root.clicked();
    }
}
