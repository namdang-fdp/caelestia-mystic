pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import "helpers/ActivityLogic.js" as Logic

ColumnLayout {
    id: root
    required property ShellScreen screen
    readonly property var monitor: Brightness.getMonitorForScreen(screen)
    signal pageRequested(string page)
    property bool menuOpen
    readonly property bool dragging: microphone.dragging || nightLightSlider.pressed
    implicitHeight: 390 + Math.max(0, trayFlow.implicitHeight - 40) + (nightLightRow.visible ? 46 : 0)
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        IslandText { Layout.fillWidth: true; text: qsTr("More controls"); islandFont: Tokens.font.title.medium }
        IslandButton { iconName: "calendar_month"; text: qsTr("Info"); onClicked: root.pageRequested("info") }
        IslandButton { iconName: "power_settings_new"; Accessible.name: qsTr("Power menu"); onClicked: root.pageRequested("power") }
    }
    Control {
        id: microphone
        label: qsTr("Microphone")
        iconName: Audio.sourceMuted ? "mic_off" : "mic"
        value: Audio.sourceVolume
        maximum: GlobalConfig.services.maxVolume
        enabled: !!Audio.source?.audio
        onMoved: value => Audio.setSourceVolume(value)
        onToggleRequested: if (Audio.source?.audio) Audio.source.audio.muted = !Audio.sourceMuted
    }
    RowLayout {
        Layout.fillWidth: true
        IslandButton { text: qsTr("Keep Awake"); iconName: "coffee"; checked: IdleInhibitor.enabled; onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled }
        IslandButton { text: qsTr("VPN"); iconName: "vpn_key"; checked: VPN.connected; enabled: VPN.enabled && !VPN.connecting; onClicked: VPN.toggle() }
        IslandButton { visible: NightLight.available; text: qsTr("Night Light"); iconName: "nightlight"; checked: NightLight.enabled; onClicked: NightLight.toggle() }
    }
    RowLayout {
        id: nightLightRow
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        Layout.topMargin: -2
        visible: NightLight.available && NightLight.enabled
        spacing: 10
        IslandSlider {
            id: nightLightSlider
            visible: !NightLight.error
            Layout.fillWidth: true
            iconName: "nightlight"
            label: qsTr("Night light temperature")
            // Left is warmer: the slider runs from the maximum down to the minimum kelvin.
            from: NightLight.maximumTemperature
            to: NightLight.minimumTemperature
            stepSize: 100
            value: NightLight.temperature
            onMoved: NightLight.setTemperature(value)
        }
        IslandText {
            Layout.fillWidth: !!NightLight.error
            Layout.preferredWidth: 56
            horizontalAlignment: NightLight.error ? Text.AlignLeft : Text.AlignRight
            text: NightLight.error ? qsTr("Night light: %1").arg(NightLight.error) : `${NightLight.temperature} K`
            color: NightLight.error ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurfaceVariant
            islandFont: Tokens.font.label.medium
            elide: Text.ElideRight
        }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 4
        IslandButton { text: qsTr("Spaces"); iconName: "grid_view"; onClicked: root.pageRequested("workspaces") }
        IslandButton { text: qsTr("Clipboard"); iconName: "content_paste"; onClicked: root.pageRequested("clipboard") }
        IslandButton { text: qsTr("Notifications"); iconName: "notifications"; onClicked: root.pageRequested("notifications") }
        IslandButton { text: qsTr("Weather"); iconName: "partly_cloudy_day"; onClicked: root.pageRequested("weather") }
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(IslandTheme.palette.m3outline, 0.16) }
    RowLayout {
        Layout.fillWidth: true
        IslandText { text: qsTr("Background apps"); islandFont: Tokens.font.label.medium; color: IslandTheme.palette.m3onSurfaceVariant }
        Item { Layout.fillWidth: true }
        IslandText { text: IslandTray.items.length; islandFont: Tokens.font.label.small; color: IslandTheme.palette.m3outline }
    }
    Flow {
        id: trayFlow
        Layout.fillWidth: true
        Layout.minimumHeight: 40
        spacing: 8
        Repeater {
            model: IslandTray.items
            IslandButton {
                id: trayButton
                required property var modelData
                implicitWidth: 40
                implicitHeight: 40
                Accessible.name: modelData.tooltipTitle || modelData.title || modelData.id
                contentItem: IconImage { source: Icons.getTrayIcon(trayButton.modelData.id, trayButton.modelData.icon); implicitSize: 24 }
                function showMenu(): void {
                    if (!modelData.hasMenu) return;
                    root.menuOpen = true;
                    nativeMenu.open();
                }
                onClicked: modelData.onlyMenu ? showMenu() : modelData.activate()
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: trayButton.showMenu() }
                TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: trayButton.modelData.secondaryActivate() }
                QsMenuAnchor {
                    id: nativeMenu
                    anchor.item: trayButton
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom
                    menu: trayButton.modelData.menu
                    onClosed: root.menuOpen = false
                }
            }
        }
        IslandText { visible: !IslandTray.items.length; text: qsTr("No background apps"); color: IslandTheme.palette.m3outline; islandFont: Tokens.font.body.small }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(IslandTheme.palette.m3outline, .16) }
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            IslandText { text: qsTr("Screen recording"); islandFont: Tokens.font.label.large }
            IslandText { text: Recorder.running ? `${Recorder.paused ? qsTr("Paused") : qsTr("Recording")} · ${Logic.clock(Recorder.elapsed)}` : qsTr("Ready when you are"); color: Recorder.running ? IslandTheme.palette.m3error : IslandTheme.palette.m3onSurfaceVariant }
        }
        IslandButton { visible: Recorder.running; enabled: !Recorder.busy; text: Recorder.paused ? qsTr("Resume") : qsTr("Pause"); iconName: Recorder.paused ? "play_arrow" : "pause"; onClicked: Recorder.togglePause() }
        IslandButton { visible: Recorder.running; enabled: !Recorder.busy; text: qsTr("Stop & save"); iconName: "stop"; onClicked: Recorder.stop() }
        IslandButton { visible: !Recorder.running; enabled: !Recorder.busy; text: qsTr("Record screen"); iconName: "screen_record"; onClicked: Recorder.start() }
    }

    component Control: ColumnLayout {
        id: control
        required property string label
        required property string iconName
        required property real value
        property real maximum: 1
        readonly property bool dragging: slider.dragging
        signal moved(real value)
        signal toggleRequested
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            IslandButton { iconName: control.iconName; Accessible.name: control.label; onClicked: control.toggleRequested() }
            IslandText { Layout.fillWidth: true; text: control.label; islandFont: Tokens.font.label.medium }
            IslandText { text: `${Math.round(control.value * 100)}%`; islandFont: Tokens.font.label.medium; color: IslandTheme.palette.m3primary }
        }
        StyledSlider {
            id: slider
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            fgColour: enabled ? IslandTheme.palette.m3onSurface : IslandTheme.palette.m3outline
            bgColour: IslandTheme.palette.m3surfaceContainerHighest
            value: control.value
            to: control.maximum
            wheelEnabled: true
            onInteraction: position => control.moved(position * to)
            onMoved: control.moved(value)
            Accessible.name: control.label
        }
    }
}
