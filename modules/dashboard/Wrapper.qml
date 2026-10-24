pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import "helpers/ActivityLogic.js" as Logic

Item {
    id: root
    required property ScreenState screenState
    required property ShellScreen screen
    property bool fullscreen
    property bool previewOpen
    property bool notificationExpanded
    property string transientIcon
    property string transientText
    property string transientDetail
    property string transientArt
    // 0..1 draws an OSD level bar; negative values are text-only feedback.
    property real transientValue: -1
    property bool feedbackReady
    property real wheelRest
    property real slideFrom
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(screen) ?? null
    readonly property real motionScale: Tokens.anim.durations.scale
    readonly property bool expanded: screenState.dashboard && Config.dashboard.enabled
    readonly property string previewPage: compact.hasMedia ? "media" : "controls"
    readonly property string page: previewOpen ? previewPage : screenState.islandPage === "media" && !Config.dashboard.showMedia ? "controls" : screenState.islandPage
    readonly property var pending: Notifs.popups.filter(n => !n.closed && (n.popupScreenName === screen.name || !Quickshell.screens.some(s => s.name === n.popupScreenName) && ShellState.forActive() === screenState))
    readonly property var foreground: pending.length ? pending[pending.length - 1] : null
    readonly property bool showingToast: !!foreground && !expanded
    readonly property bool showingFeedback: feedbackTimer.running && !expanded && !showingToast && !previewOpen
    readonly property bool feedbackLevel: transientValue >= 0
    readonly property bool feedbackTrack: !!transientArt || transientIcon === "music_note" && !!transientDetail
    readonly property string mode: expanded ? page : showingToast ? "notification" : previewOpen ? "peek" : showingFeedback ? "feedback" : "compact"
    readonly property bool previewAllowed: Config.dashboard.enabled && Config.dashboard.showOnHover && !fullscreen
    readonly property bool interactionHovered: hover.hovered
    readonly property bool popupHovered: showingToast && interactionHovered
    readonly property alias hovered: hover.hovered
    readonly property bool shouldBeActive: expanded
    readonly property real offsetScale: visible ? 0 : 1
    readonly property real nonAnimHeight: implicitHeight
    readonly property real surfaceRadius: surface.radius
    readonly property bool nativeMenuOpen: pane.item?.menuOpen ?? false
    readonly property bool dragging: pane.item?.dragging ?? false
    readonly property string brightnessTarget: pane.item?.monitor?.modelData?.name ?? ""
    readonly property var trayItems: IslandTray.items
    readonly property bool keepsAwake: IdleInhibitor.enabled
    readonly property string activity: compact.activity
    readonly property string restingMode: compact.restingMode
    readonly property bool basicPage: page === "controls" || page === "media"
    // Pages that draw their own back/title row.
    readonly property bool ownHeader: basicPage || ["wifi", "bluetooth", "timer"].includes(page)
    readonly property real contentY: ownHeader ? 14 : 46
    readonly property real padding: basicPage ? 16 : 20
    readonly property real paneHeight: pane.item?.implicitHeight ?? (page === "controls" ? 286 : page === "media" ? 188 : 304)
    readonly property real pageWidth: ({ controls: 424, media: 400, more: 448, info: 540, clipboard: 520, notifications: 480, workspaces: 744, power: 400, wifi: 404, bluetooth: 404, timer: 404, weather: 440 })[page] ?? 424
    readonly property real feedbackWidth: feedbackTrack ? 380 : feedbackLevel ? 300 : 280
    readonly property real targetWidth: expanded || previewOpen ? pageWidth : showingToast ? notificationExpanded ? 480 : 360 : showingFeedback ? feedbackWidth : compact.implicitWidth
    readonly property real targetHeight: expanded || previewOpen ? paneHeight + contentY + 16 : showingToast ? notification.itemAt(0)?.implicitHeight ?? 76 : showingFeedback ? feedbackTrack ? 60 : 40 : 36
    implicitWidth: Math.min(screen.width - 32, targetWidth)
    implicitHeight: Math.min(screen.height - 32, targetHeight)
    visible: Config.dashboard.enabled && (!fullscreen || expanded || WindowUx.resizing) || !!foreground
    anchors.topMargin: 8

    function depth(name: string): int { return name === "controls" || name === "media" ? 0 : name === "more" ? 1 : 2; }
    function openPage(name: string): void {
        if (!Config.dashboard.enabled) return;
        if (name === "connections") name = "wifi";
        previewOpen = false;
        screenState.launcher = false;
        screenState.islandPage = name === "media" && !Config.dashboard.showMedia ? "controls" : name;
        screenState.dashboard = true;
    }
    function toggleDetail(section: string): void {
        if (expanded && page === section) openPage("controls");
        else openPage(section);
    }
    function close(): void {
        screenState.dashboard = false;
        previewOpen = false;
        enterDelay.stop();
    }
    function closeTop(): void {
        if (expanded && ["wifi", "bluetooth", "timer"].includes(page)) openPage("controls");
        else close();
    }
    function feedback(iconName: string, text: string, value = -1, detail = "", art = "", duration = 1400): void {
        if (!feedbackReady || fullscreen || !Config.dashboard.enabled || Hypr.focusedMonitor !== monitor || expanded || showingToast) return;
        transientIcon = iconName; transientText = text; transientValue = value; transientDetail = detail; transientArt = art;
        feedbackTimer.interval = duration;
        feedbackTimer.restart();
    }
    function stepVolume(steps: int): void {
        if (!Audio.sink?.audio || !steps) return;
        Audio.setVolume(Logic.clampUnit(Audio.volume + steps * .05));
    }
    onPopupHoveredChanged: {
        if (foreground) {
            if (popupHovered) foreground.timer.stop();
            else foreground.timer.start();
        }
    }
    onForegroundChanged: { notificationExpanded = false; if (foreground && popupHovered) foreground.timer.stop(); }
    onPreviewOpenChanged: {
        if (previewOpen) releaseDelay.stop();
        else if (!expanded && pane.active) releaseDelay.restart();
    }
    onExpandedChanged: {
        previewOpen = false;
        if (expanded) { releaseDelay.stop(); forceActiveFocus(); }
        else if (pane.active) releaseDelay.restart();
    }
    onPreviewAllowedChanged: if (!previewAllowed) previewOpen = false
    onShowingToastChanged: { previewOpen = false; enterDelay.stop(); }
    onVisibleChanged: if (!visible) previewOpen = false
    property string lastPage: page
    onPageChanged: {
        // Drilling in slides content from the right, going back from the left.
        const delta = depth(page) - depth(lastPage);
        slideFrom = expanded && delta ? (delta > 0 ? 28 : -28) : 0;
        lastPage = page;
        contentExit.stop(); contentFade.restart();
        if (expanded) forceActiveFocus();
    }
    onModeChanged: {
        if (mode === "compact" || mode === "feedback") { contentFade.stop(); contentExit.restart(); }
        else { contentExit.stop(); contentFade.restart(); }
    }
    onInteractionHoveredChanged: {
        if (interactionHovered) leaveDelay.stop();
        else { enterDelay.stop(); leaveDelay.restart(); }
    }
    onDraggingChanged: if (!dragging && !interactionHovered) leaveDelay.restart()
    Keys.onEscapePressed: event => { closeTop(); event.accepted = true; }
    Component.onCompleted: feedbackWarmup.start()

    Behavior on implicitWidth { NumberAnimation { duration: 380 * root.motionScale; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 380 * root.motionScale; easing.type: Easing.OutCubic } }
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.expanded || root.previewOpen ? 24 : root.notificationExpanded ? 24 : root.targetHeight / 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#101214" }
            GradientStop { position: 1; color: "#050607" }
        }
        border.width: 1
        border.color: root.showingToast && (notification.itemAt(0)?.critical ?? false) ? Qt.alpha(IslandTheme.palette.m3error, .55) : Qt.alpha("white", root.expanded || root.previewOpen ? .1 : .06)
        Behavior on radius { NumberAnimation { duration: 380 * root.motionScale; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 200 * root.motionScale } }
    }
    HoverHandler {
        id: hover
        cursorShape: root.expanded || root.previewOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered && root.previewAllowed && !root.expanded && !root.showingToast) enterDelay.restart();
        }
    }
    // Over the resting pill: scroll changes volume, sideways scroll (or
    // Shift+scroll) switches between clock, lyrics and system stats.
    WheelHandler {
        enabled: !root.expanded && !root.previewOpen && !root.showingToast
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const sideways = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) || event.modifiers & Qt.ShiftModifier;
            if (sideways) {
                const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? -event.angleDelta.x : event.angleDelta.y;
                const result = Logic.wheelSteps(root.wheelRest, delta);
                root.wheelRest = result.rest;
                if (result.steps && !modeCooldown.running) {
                    compact.cycleMode(result.steps > 0 ? -1 : 1);
                    modeCooldown.restart();
                    root.wheelRest = 0;
                    root.feedback(compact.restingMode === "lyrics" ? "lyrics" : compact.restingMode === "stats" ? "monitoring" : "schedule", compact.restingMode === "lyrics" ? qsTr("Lyrics") : compact.restingMode === "stats" ? qsTr("System stats") : qsTr("Clock"), -1, "", "", 900);
                }
                return;
            }
            const result = Logic.wheelSteps(root.wheelRest, event.angleDelta.y);
            root.wheelRest = result.rest;
            root.stepVolume(result.steps);
        }
    }
    Timer { id: modeCooldown; interval: 350 }
    Timer { id: enterDelay; interval: 260; onTriggered: if (hover.hovered && root.previewAllowed && !root.expanded && !root.showingToast) root.previewOpen = true }
    Timer { id: leaveDelay; interval: 300; onTriggered: if (!root.interactionHovered && !root.dragging && !root.nativeMenuOpen) root.previewOpen = false }
    Timer { id: releaseDelay; interval: Math.max(1, 420 * root.motionScale) }
    Timer { id: feedbackTimer; interval: 1400 }
    Timer { id: feedbackWarmup; interval: 800; onTriggered: root.feedbackReady = true }
    Connections {
        target: Audio
        function onVolumeChanged(): void { root.feedback(Audio.muted ? "volume_off" : Audio.volume < .34 ? "volume_mute" : Audio.volume < .67 ? "volume_down" : "volume_up", qsTr("Volume"), Audio.muted ? 0 : Audio.volume); }
        function onMutedChanged(): void { root.feedback(Audio.muted ? "volume_off" : "volume_up", Audio.muted ? qsTr("Muted") : qsTr("Sound on"), Audio.muted ? 0 : Audio.volume); }
        function onSourceMutedChanged(): void { root.feedback(Audio.sourceMuted ? "mic_off" : "mic", Audio.sourceMuted ? qsTr("Microphone off") : qsTr("Microphone on")); }
    }
    Connections {
        target: root.monitor
        function onActiveWorkspaceChanged(): void { root.feedback("grid_view", qsTr("Workspace %1").arg(root.monitor?.activeWorkspace?.id ?? 1)); }
    }
    Connections {
        target: root.brightnessMonitor
        function onBrightnessChanged(): void { root.feedback("brightness_6", qsTr("Brightness"), root.brightnessMonitor.brightness); }
    }
    Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            const level = Math.round(UPower.displayDevice.percentage * 100);
            if (!UPower.displayDevice.isLaptopBattery) return;
            root.feedback(UPower.onBattery ? "power_off" : "bolt", UPower.onBattery ? qsTr("On battery") : qsTr("Charging"), UPower.displayDevice.percentage, `${level}%`, "", 2200);
        }
    }
    Connections {
        target: Players.active
        function onTrackTitleChanged(): void {
            const player = Players.active;
            if (!player?.isPlaying || !player.trackTitle || compact.restingMode === "lyrics") return;
            root.feedback("music_note", player.trackTitle, -1, player.trackArtist || Players.getIdentity(player), Players.getArtUrl(player), 2600);
        }
    }
    Connections {
        target: IslandTimer
        function onFinished(phase: string, pomodoro: bool): void {
            root.feedback("alarm", !pomodoro ? qsTr("Time's up") : phase === "focus" ? qsTr("Focus done · take a break") : qsTr("Break over · back to focus"), -1, "", "", 3200);
        }
    }
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property BluetoothDevice modelData
            target: modelData
            function onConnectedChanged(): void {
                if (!modelData.paired && !modelData.bonded) return;
                root.feedback(Logic.bluetoothIcon(modelData.icon), modelData.name || modelData.deviceName, modelData.connected && modelData.batteryAvailable ? modelData.battery : -1, modelData.connected ? qsTr("Connected") : qsTr("Disconnected"), "", 2000);
            }
        }
    }
    TapHandler {
        enabled: !root.expanded && !root.showingToast
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onTapped: (point, button) => root.openPage(button === Qt.RightButton ? "controls" : button === Qt.MiddleButton ? "workspaces" : root.activity === "timer" ? "timer" : compact.hasMedia ? "media" : "controls")
    }
    Item {
        anchors.fill: parent
        clip: true
        IslandCompact {
            id: compact
            anchors.centerIn: parent
            height: 36
            opacity: root.mode === "compact" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160 * root.motionScale; easing.type: Easing.OutCubic } }
            audioVisible: visible && root.visible
            monitorAudio: root.visible
        }
        // Transient feedback: text pill, OSD level bar, or now-playing card.
        Item {
            id: feedbackView
            anchors.fill: parent
            opacity: root.showingFeedback ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 140 * root.motionScale; easing.type: Easing.OutCubic } }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.feedbackTrack ? 10 : 16; anchors.rightMargin: 16
                spacing: 10
                IslandText { visible: !root.feedbackLevel && !root.feedbackTrack; text: Time.timeStr; font.pixelSize: 14; font.weight: Font.DemiBold }
                Rectangle { visible: !root.feedbackLevel && !root.feedbackTrack; implicitWidth: 1; implicitHeight: 14; color: IslandTheme.palette.divider }
                ClippingRectangle {
                    visible: root.feedbackTrack
                    implicitWidth: 40; implicitHeight: 40; radius: 10
                    color: IslandTheme.palette.chip
                    Image { anchors.fill: parent; source: root.transientArt; sourceSize: Qt.size(80, 80); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    MaterialIcon { anchors.centerIn: parent; visible: !root.transientArt; text: "music_note"; color: IslandTheme.palette.m3primary; fontStyle: Tokens.font.icon.medium }
                }
                MaterialIcon { visible: !root.feedbackTrack; text: root.transientIcon; color: root.transientIcon === "bolt" ? IslandTheme.palette.success : IslandTheme.palette.m3primary; fontStyle: Tokens.font.icon.small }
                ColumnLayout {
                    Layout.fillWidth: !root.feedbackLevel
                    spacing: 0
                    IslandText { Layout.fillWidth: true; visible: root.feedbackTrack; text: qsTr("Now playing"); font.pixelSize: 10; color: IslandTheme.palette.m3onSurfaceVariant }
                    IslandText { Layout.fillWidth: true; Layout.maximumWidth: root.feedbackLevel ? 96 : 300; text: root.transientText; font.pixelSize: root.feedbackTrack ? 13 : 12; font.weight: root.feedbackTrack ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
                    IslandText { Layout.fillWidth: true; visible: root.feedbackTrack && !!root.transientDetail; text: root.transientDetail; font.pixelSize: 11; color: IslandTheme.palette.m3onSurfaceVariant; elide: Text.ElideRight }
                }
                Rectangle {
                    visible: root.feedbackLevel
                    Layout.fillWidth: true
                    implicitHeight: 6; radius: 3
                    color: IslandTheme.palette.track
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: parent.width * Logic.clampUnit(root.transientValue)
                        color: root.transientIcon === "bolt" ? IslandTheme.palette.success : IslandTheme.palette.trackFill
                        Behavior on width { NumberAnimation { duration: 120 * root.motionScale; easing.type: Easing.OutCubic } }
                    }
                }
                IslandText {
                    visible: root.feedbackLevel || !root.feedbackTrack && !!root.transientDetail
                    Layout.minimumWidth: root.feedbackLevel ? 34 : 0
                    horizontalAlignment: Text.AlignRight
                    text: root.feedbackLevel && !root.transientDetail ? `${Math.round(Logic.clampUnit(root.transientValue) * 100)}%` : root.transientDetail
                    font.pixelSize: 12; font.features: { "tnum": 1 }
                    color: IslandTheme.palette.m3onSurfaceVariant
                }
            }
        }
        Item {
            id: animatedContent
            anchors.fill: parent
            SequentialAnimation {
                id: contentFade
                PropertyAction { target: animatedContent; property: "opacity"; value: 0 }
                PropertyAction { target: slide; property: "x"; value: root.slideFrom }
                PauseAnimation { duration: 70 * root.motionScale }
                ParallelAnimation {
                    NumberAnimation { target: animatedContent; property: "opacity"; to: 1; duration: 210 * root.motionScale; easing.type: Easing.OutCubic }
                    NumberAnimation { target: slide; property: "x"; to: 0; duration: 300 * root.motionScale; easing.type: Easing.OutCubic }
                }
            }
            NumberAnimation { id: contentExit; target: animatedContent; property: "opacity"; to: 0; duration: 100 * root.motionScale; easing.type: Easing.OutCubic }
            transform: Translate { id: slide }
            RowLayout {
                x: 12; y: 8; width: parent.width - 24; height: 30
                visible: (root.expanded || root.previewOpen) && !root.ownHeader
                IslandButton { iconName: "chevron_left"; implicitHeight: 28; leftPadding: 4; rightPadding: 4; Accessible.name: qsTr("Back to Control Center"); onClicked: root.openPage("controls") }
                IslandText { Layout.fillWidth: true; text: ({ more: qsTr("Controls"), info: qsTr("Info"), clipboard: qsTr("Clipboard"), notifications: qsTr("Notifications"), workspaces: qsTr("Windows"), power: qsTr("Power"), weather: qsTr("Weather") })[root.page] ?? ""; font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant }
                IslandButton { iconName: "close"; implicitHeight: 28; leftPadding: 4; rightPadding: 4; Accessible.name: qsTr("Close Island"); onClicked: root.close() }
            }
            Loader {
                id: pane
                x: (parent.width - width) / 2; y: root.contentY
                width: Math.max(0, Math.min(root.screen.width - 32, root.pageWidth) - root.padding * 2)
                height: root.paneHeight
                active: root.expanded || root.previewOpen || releaseDelay.running
                visible: active
                enabled: root.expanded || root.previewOpen
                sourceComponent: ({ wifi: wifiPane, bluetooth: bluetoothPane, timer: timerPane, weather: weatherPane, clipboard: clipboardPane, media: mediaPane, info: infoPane, more: morePane, controls: controlsPane, notifications: notificationsPane, power: powerPane })[root.page] ?? workspacePane
            }
            Component { id: controlsPane; IslandControlsView { screen: root.screen; onPageRequested: page => root.openPage(page); onDetailRequested: section => root.toggleDetail(section); onCloseRequested: root.close() } }
            Component { id: morePane; IslandMoreView { screen: root.screen; onPageRequested: page => root.openPage(page) } }
            Component { id: workspacePane; IslandWorkspacesView { screen: root.screen; interactiveFocus: root.expanded; layoutTargetWidth: Math.min(root.screen.width - 32, 744) - 40; onCloseRequested: root.close() } }
            Component { id: wifiPane; IslandWifiView { onBackRequested: root.openPage("controls"); onCloseRequested: root.close() } }
            Component { id: bluetoothPane; IslandBluetoothView { onBackRequested: root.openPage("controls"); onCloseRequested: root.close() } }
            Component { id: timerPane; IslandTimerView { onBackRequested: root.openPage("controls") } }
            Component { id: weatherPane; IslandWeatherView { onPageRequested: page => root.openPage(page) } }
            Component { id: notificationsPane; IslandNotificationsView { screenState: root.screenState } }
            Component { id: powerPane; IslandPowerView { onCloseRequested: root.close() } }
            Component { id: mediaPane; IslandMediaView { onPageRequested: page => root.openPage(page) } }
            Component { id: infoPane; IslandInfoView { screenState: root.screenState; onPageRequested: page => root.openPage(page) } }
            Component { id: clipboardPane; IslandClipboardView { onCloseRequested: root.close() } }
            Repeater {
                id: notification
                model: ScriptModel { values: root.showingToast ? [root.foreground] : [] }
                IslandNotification {
                    required property var modelData
                    notification: modelData
                    waiting: root.pending.length - 1
                    detailed: root.notificationExpanded
                    width: root.width; height: root.height
                    onExpansionRequested: root.notificationExpanded = !root.notificationExpanded
                }
            }
        }
    }
}
