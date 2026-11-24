pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "helpers/AgentLogic.js" as Logic

Item {
    id: root
    required property Item island
    required property bool available
    readonly property alias noticeSurface: toast
    readonly property real motionScale: Tokens.anim.durations.scale
    readonly property var pets: AgentState.companion.pets
    readonly property var notice: AgentState.companion.notice
    readonly property int petCount: Logic.COMPANIONS.filter(agent => pets[agent].state !== "").length
    readonly property real dockX: island.x + island.width + island.surfaceEar + capsule.ear + 4
    readonly property real targetWidth: 12 + Math.max(1, petCount) * 46
    readonly property bool active: available && petCount > 0 && dockX + targetWidth + capsule.ear <= parent.width - 6
    property real progress: active ? 1 : 0
    readonly property color material: IslandTools.glass ? IslandTheme.palette.glass : IslandTheme.palette.m3surfaceContainer
    readonly property color edge: Qt.alpha("white", IslandTools.glass ? .18 : .07)
    readonly property color shadowColor: Qt.alpha("black", IslandTools.glass ? .3 : .76)
    readonly property bool showNotice: active && progress > .89 && !!notice
    property var shownNotice: null

    objectName: "islandAgentCompanion"
    width: targetWidth
    height: 36
    x: island.x + island.width - width * .62 + (dockX - (island.x + island.width - width * .62)) * progress
    y: 0
    visible: available && progress > .01
    opacity: Math.min(1, progress * 1.3)
    Behavior on width {
        enabled: root.motionScale > 0
        SpringAnimation { spring: 4; damping: .4; epsilon: .25 }
    }
    Behavior on progress {
        enabled: root.motionScale > 0
        SpringAnimation { spring: 4; damping: .42; epsilon: .006 }
    }
    onNoticeChanged: if (notice) shownNotice = notice

    Rectangle {
        id: toast
        readonly property bool interactive: root.showNotice && opacity > .9
        objectName: "islandAgentToast"
        x: Math.min(0, root.parent.width - root.x - width - 10)
        y: root.height + 6 - 22 * (1 - opacity)
        width: Math.min(288, root.parent.width - 20)
        height: toastContent.implicitHeight + 20
        radius: 18
        color: root.material
        border.width: 1
        border.color: root.edge
        visible: opacity > .01
        opacity: root.showNotice ? 1 : 0
        enabled: interactive
        Behavior on opacity {
            NumberAnimation { duration: 210 * root.motionScale; easing.type: Easing.OutCubic }
        }
        RectangularShadow {
            z: -1
            anchors.fill: parent
            radius: toast.radius
            blur: 26
            spread: -8
            offset.y: 8
            color: root.shadowColor
        }
        RowLayout {
            id: toastContent
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 10
                color: Qt.alpha(mark.color, .16)
                MaterialIcon {
                    id: mark
                    anchors.centerIn: parent
                    text: root.shownNotice?.type === "waiting" ? "front_hand" : "check"
                    color: root.shownNotice?.type === "waiting" ? IslandTheme.palette.warning : IslandTheme.palette.success
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                IslandText {
                    Layout.fillWidth: true
                    text: root.shownNotice?.type === "waiting"
                        ? qsTr("%1 needs you").arg(Logic.agentName(root.shownNotice.session.agent))
                        : root.shownNotice?.count > 1 ? qsTr("%1 · %2 tasks finished").arg(Logic.agentName(root.shownNotice.session.agent)).arg(root.shownNotice.count)
                        : root.shownNotice ? qsTr("%1 finished").arg(Logic.agentName(root.shownNotice.session.agent)) : ""
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                IslandText {
                    Layout.fillWidth: true
                    visible: !!text
                    text: [root.shownNotice?.session?.project, root.shownNotice?.type === "waiting" ? root.shownNotice.session.tool : ""].filter(Boolean).join(" · ")
                    color: IslandTheme.palette.m3onSurfaceVariant
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            IslandButton {
                iconName: "close"
                leftPadding: 5
                rightPadding: 5
                implicitHeight: 28
                Accessible.name: qsTr("Dismiss agent notification")
                onClicked: AgentState.dismissCompanionNotice(root.notice)
            }
        }
    }

    IslandNotch {
        id: capsule
        anchors.fill: parent
    }
    Row {
        anchors.centerIn: parent
        Repeater {
            model: Logic.COMPANIONS
            Item {
                id: slot
                required property string modelData
                readonly property var pet: root.pets[modelData]
                property real presence: pet.state ? 1 : 0
                property string pose: "idle"
                onPetChanged: if (pet.state) pose = pet.state
                Component.onCompleted: if (pet.state) pose = pet.state
                width: 46 * presence
                height: root.height
                opacity: Math.min(1, presence * 1.25)
                visible: presence > .015
                Behavior on presence {
                    NumberAnimation { duration: 210 * root.motionScale; easing.type: Easing.OutCubic }
                }
                Accessible.role: Accessible.Indicator
                Accessible.name: qsTr("%1 · %2").arg(Logic.agentName(modelData)).arg(Logic.stateLabel(pose))
                IslandAgentSprite {
                    anchors.centerIn: parent
                    width: 34
                    height: 36
                    agent: slot.modelData
                    state: slot.pose
                    playing: root.visible && slot.visible
                    travel: root.progress < .92 ? root.active ? "right" : "left" : ""
                }
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    visible: slot.pose === "waiting" || slot.pet.count > 1
                    color: slot.pose === "waiting" ? IslandTheme.palette.warning : IslandTheme.palette.chip
                    IslandText {
                        anchors.centerIn: parent
                        text: slot.pose === "waiting" ? "!" : slot.pet.count < 10 ? String(slot.pet.count) : "+"
                        color: slot.pose === "waiting" ? "#101010" : IslandTheme.palette.m3onSurface
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}
