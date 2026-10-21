pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root
    readonly property var profiles: [
        { value: PowerProfile.PowerSaver, label: qsTr("Power saver"), iconName: "energy_savings_leaf" },
        { value: PowerProfile.Balanced, label: qsTr("Balanced"), iconName: "balance" },
        { value: PowerProfile.Performance, label: qsTr("Performance"), iconName: "rocket_launch" }
    ]
    readonly property var current: profiles.find(p => p.value === PowerProfiles.profile) ?? profiles[1]
    readonly property bool degraded: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        MaterialIcon { text: root.current.iconName; color: IslandTheme.palette.m3primary; fontStyle: Tokens.font.icon.small }
        IslandText {
            Layout.fillWidth: true
            text: root.current.label
            islandFont: Tokens.font.label.medium
            color: IslandTheme.palette.m3primary
            elide: Text.ElideRight
            Accessible.name: qsTr("Power profile: %1").arg(text)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: root.profiles
            IslandButton {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                iconName: modelData.iconName
                checked: PowerProfiles.profile === modelData.value
                enabled: modelData.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                Accessible.name: qsTr("Set power profile to %1").arg(modelData.label)
                onClicked: PowerProfiles.profile = modelData.value
            }
        }
    }
    IslandText {
        Layout.fillWidth: true
        visible: root.degraded
        text: qsTr("Performance limited: %1").arg(PerformanceDegradationReason.toString(PowerProfiles.degradationReason))
        islandFont: Tokens.font.label.small
        color: IslandTheme.palette.m3error
        wrapMode: Text.WordWrap
    }
}
