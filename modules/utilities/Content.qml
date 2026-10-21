import "cards"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

Item {
    id: root

    required property var props
    required property ScreenState screenState
    required property matrix4x4 deformMatrix

    readonly property real nonAnimHeight: idleInhibit.nonAnimHeight + record.nonAnimHeight + toggles.implicitHeight + layout.spacing * 2

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        IdleInhibit {
            id: idleInhibit

            objectName: "utilitiesKeepAwake"
        }

        Record {
            id: record

            objectName: "utilitiesScreenRecorder"

            props: root.props
            screenState: root.screenState
            z: 1
        }

        Toggles {
            id: toggles

            objectName: "utilitiesQuickToggles"

            screenState: root.screenState
        }
    }

    RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }
}
