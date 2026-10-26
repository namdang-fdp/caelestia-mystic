pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
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
    // A file dragged onto the resting island opens the shelf as a peek; it
    // stays on the shelf until that peek closes.
    property bool fileDragOver
    property bool shelfPeek
    readonly property bool exporting: pane.item?.exporting ?? false
    // Also instantiates the shelf at startup, for its IPC and stale-file check.
    readonly property int shelfCount: IslandShelf.count
    // Clicking opens these pages as a carousel with page dots. Hovering only
    // peeks at what is happening now: music, a timer, the shelf, or a glance.
    readonly property var carousel: ["controls", ...(Config.dashboard.showMedia ? ["media"] : []), "timer", "shelf", "clipboard", "workspaces", "more"]
    readonly property int carouselIndex: expanded ? carousel.indexOf(page) : -1
    readonly property bool inCarousel: carouselIndex >= 0
    readonly property string nowPage: shelfPeek ? "shelf" : compact.hasMedia && Config.dashboard.showMedia ? "media" : IslandTimer.active ? "timer" : IslandShelf.count ? "shelf" : "glance"
    readonly property string previewPage: nowPage
    readonly property string page: previewOpen ? previewPage : screenState.islandPage === "media" && !Config.dashboard.showMedia ? "controls" : screenState.islandPage
    readonly property var pending: Notifs.popups.filter(n => !n.closed && (n.popupScreenName === screen.name || !Quickshell.screens.some(s => s.name === n.popupScreenName) && ShellState.forActive() === screenState))
    readonly property var foreground: pending.length ? pending[pending.length - 1] : null
    readonly property bool showingToast: !!foreground && !expanded
    readonly property bool showingFeedback: feedbackTimer.running && !expanded && !showingToast && !previewOpen
    readonly property bool feedbackLevel: transientValue >= 0
    readonly property bool feedbackTrack: !!transientArt || transientIcon === "music_note" && !!transientDetail
    readonly property string mode: expanded ? page : showingToast ? "notification" : previewOpen ? "peek" : showingFeedback ? "feedback" : "compact"
    readonly property bool previewAllowed: Config.dashboard.enabled && Config.dashboard.showOnHover && !fullscreen
    readonly property bool interactionHovered: hover.hovered || fileDragOver
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
    readonly property bool ownHeader: basicPage || ["wifi", "bluetooth", "timer", "more", "glance"].includes(page)
    readonly property real dotsHeight: inCarousel ? 18 : 0
    readonly property real contentY: ownHeader ? 14 : 46
    readonly property real padding: basicPage ? 16 : 20
    readonly property real paneHeight: pane.item?.implicitHeight ?? (page === "controls" ? 286 : page === "media" ? 188 : 304)
    readonly property real pageWidth: ({ controls: 424, media: 400, more: 448, info: 540, clipboard: 520, notifications: 480, workspaces: 744, power: 400, wifi: 404, bluetooth: 404, timer: 404, weather: 440, shelf: 420, glance: 340 })[page] ?? 424
    readonly property real feedbackWidth: feedbackTrack ? 380 : feedbackLevel ? 300 : 280
    readonly property real targetWidth: expanded || previewOpen ? pageWidth : showingToast ? notificationExpanded ? 480 : 360 : showingFeedback ? feedbackWidth : compact.implicitWidth
    readonly property real targetHeight: expanded || previewOpen ? paneHeight + contentY + 16 + dotsHeight : showingToast ? notification.itemAt(0)?.implicitHeight ?? 76 : showingFeedback ? feedbackTrack ? 60 : 40 : 36
    implicitWidth: Math.min(screen.width - 32, targetWidth)
    implicitHeight: Math.min(screen.height - 32, targetHeight)
    visible: Config.dashboard.enabled && (!fullscreen || expanded || WindowUx.resizing) || !!foreground
    anchors.topMargin: 0

    // Detail pages and the carousel page they belong to.
    function parentPage(name: string): string {
        return ({ wifi: "controls", bluetooth: "controls", info: "controls", power: "more", notifications: "more", weather: "more" })[name] ?? "";
    }
    function depth(name: string): int { return parentPage(name) ? 1 : 0; }
    function stepPage(direction: int): void {
        if (!inCarousel) return;
        const next = carouselIndex + direction;
        if (next >= 0 && next < carousel.length) openPage(carousel[next]);
    }
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
        if (expanded && parentPage(page)) openPage(parentPage(page));
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
        if (!previewOpen) shelfPeek = false;
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
        // Drilling in or moving right through the carousel slides content in
        // from the right; going back or left slides it in from the left.
        const from = carousel.indexOf(lastPage), to = carousel.indexOf(page);
        const delta = from >= 0 && to >= 0 ? to - from : depth(page) - depth(lastPage);
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
    onExportingChanged: if (!exporting && !interactionHovered) leaveDelay.restart()
    Keys.onEscapePressed: event => { closeTop(); event.accepted = true; }
    // A/D turn pages like ←/→; text fields get the letters first.
    Keys.onPressed: event => {
        if (!inCarousel || event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return;
        if (event.key === Qt.Key_A) { stepPage(-1); event.accepted = true; }
        else if (event.key === Qt.Key_D) { stepPage(1); event.accepted = true; }
    }
    Keys.onLeftPressed: event => { event.accepted = inCarousel; stepPage(-1); }
    Keys.onRightPressed: event => { event.accepted = inCarousel; stepPage(1); }
    Component.onCompleted: feedbackWarmup.start()

    // Springs keep their velocity when retargeted mid-morph and overshoot a
    // little while growing; shrinking is damped harder so the pill never dips.
    component IslandSpring: SpringAnimation {
        property real motionScale: 1
        property bool growing: true
        spring: 4 / (motionScale * motionScale)
        damping: (growing ? .32 : .45) / motionScale
        epsilon: .25
    }
    property bool widthGrowing: true
    property bool heightGrowing: true
    onTargetWidthChanged: widthGrowing = targetWidth > implicitWidth
    onTargetHeightChanged: heightGrowing = targetHeight > implicitHeight
    Behavior on implicitWidth { enabled: root.motionScale > 0; IslandSpring { motionScale: root.motionScale; growing: root.widthGrowing } }
    Behavior on implicitHeight { enabled: root.motionScale > 0; IslandSpring { motionScale: root.motionScale; growing: root.heightGrowing } }
    // Pure black notch hanging from the top edge, like Nusa: square top
    // corners, concave "ears" joining the screen edge, rounded bottom. Only a
    // critical notification tints its outline.
    RectangularShadow {
        anchors.fill: surface
        radius: surface.radius
        blur: 34
        spread: -12
        offset.y: 14
        color: Qt.alpha("black", .9)
    }
    Item {
        id: surface
        readonly property bool critical: root.showingToast && (notification.itemAt(0)?.critical ?? false)
        property real radius: root.expanded || root.previewOpen ? 30 : root.notificationExpanded ? 26 : root.targetHeight / 2
        // Ear size follows the corner radius, never taller than the straight side.
        readonly property real ear: Math.max(0, Math.min(radius * .7, height - radius, 22))
        readonly property real r: Math.min(radius, width / 2, height)
        anchors.fill: parent
        Behavior on radius { enabled: root.motionScale > 0; IslandSpring { motionScale: root.motionScale; growing: false } }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: IslandTheme.palette.m3surfaceContainer
                strokeColor: surface.critical ? Qt.alpha(IslandTheme.palette.m3error, .55) : "transparent"
                strokeWidth: surface.critical ? 1 : 0
                startX: -surface.ear; startY: 0
                PathLine { x: surface.width + surface.ear; y: 0 }
                PathArc { x: surface.width; y: surface.ear; radiusX: surface.ear; radiusY: surface.ear; direction: PathArc.Counterclockwise }
                PathLine { x: surface.width; y: surface.height - surface.r }
                PathArc { x: surface.width - surface.r; y: surface.height; radiusX: surface.r; radiusY: surface.r }
                PathLine { x: surface.r; y: surface.height }
                PathArc { x: 0; y: surface.height - surface.r; radiusX: surface.r; radiusY: surface.r }
                PathLine { x: 0; y: surface.ear }
                PathArc { x: -surface.ear; y: 0; radiusX: surface.ear; radiusY: surface.ear; direction: PathArc.Counterclockwise }
            }
        }
    }
    HoverHandler {
        id: hover
        cursorShape: root.expanded || root.previewOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered && root.previewAllowed && !root.expanded && !root.showingToast) enterDelay.restart();
            if (hovered && root.mode === "compact") compact.greet();
        }
    }
    // Over the resting pill: scroll changes volume, sideways scroll (or
    // Shift+scroll) switches between the companion, lyrics and system stats.
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
                    const faces = { lyrics: ["lyrics", qsTr("Lyrics")], stats: ["monitoring", qsTr("System stats")], auto: ["schedule", qsTr("Clock")] };
                    const face = faces[compact.restingMode] ?? faces.auto;
                    root.feedback(face[0], face[1], -1, "", "", 900);
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
    Timer { id: leaveDelay; interval: 300; onTriggered: if (!root.interactionHovered && !root.dragging && !root.exporting && !root.nativeMenuOpen) root.previewOpen = false }
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
    DropArea {
        anchors.fill: parent
        enabled: Config.dashboard.enabled
        onEntered: drag => {
            // Ignore drags without files and the shelf's own rows coming back.
            if (!drag.hasUrls || root.exporting) { drag.accepted = false; return; }
            drag.accept(Qt.CopyAction);
            root.fileDragOver = true;
            if (root.expanded) root.openPage("shelf");
            else { root.shelfPeek = true; root.previewOpen = true; }
        }
        onExited: root.fileDragOver = false
        onDropped: drop => {
            root.fileDragOver = false;
            const paths = Logic.localPaths(drop.urls);
            if (!paths.length) return;
            IslandShelf.add(paths);
            drop.accept(Qt.CopyAction);
        }
    }
    TapHandler {
        enabled: !root.expanded && !root.showingToast
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onTapped: (point, button) => root.openPage(button === Qt.RightButton ? "controls" : button === Qt.MiddleButton ? "workspaces" : root.nowPage === "glance" ? "controls" : root.nowPage)
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
            focusedScreen: Hypr.focusedMonitor === root.monitor
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
            // Content settles in from slightly smaller and out of focus while the
            // surface morphs; the blur layer only exists during the transition.
            property real blur
            anchors.fill: parent
            transformOrigin: Item.Top
            layer.enabled: blur > 0
            layer.effect: MultiEffect { blurEnabled: true; blur: animatedContent.blur; blurMax: 24 }
            SequentialAnimation {
                id: contentFade
                PropertyAction { target: animatedContent; property: "opacity"; value: 0 }
                PropertyAction { target: animatedContent; property: "scale"; value: root.slideFrom ? 1 : .94 }
                PropertyAction { target: animatedContent; property: "blur"; value: root.motionScale > 0 ? .5 : 0 }
                PropertyAction { target: slide; property: "x"; value: root.slideFrom }
                PauseAnimation { duration: 60 * root.motionScale }
                ParallelAnimation {
                    NumberAnimation { target: animatedContent; property: "opacity"; to: 1; duration: 220 * root.motionScale; easing.type: Easing.OutCubic }
                    NumberAnimation { target: animatedContent; property: "scale"; to: 1; duration: 340 * root.motionScale; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    NumberAnimation { target: animatedContent; property: "blur"; to: 0; duration: 260 * root.motionScale; easing.type: Easing.OutCubic }
                    NumberAnimation { target: slide; property: "x"; to: 0; duration: 300 * root.motionScale; easing.type: Easing.OutCubic }
                }
            }
            ParallelAnimation {
                id: contentExit
                NumberAnimation { target: animatedContent; property: "opacity"; to: 0; duration: 100 * root.motionScale; easing.type: Easing.OutCubic }
                NumberAnimation { target: animatedContent; property: "scale"; to: .96; duration: 120 * root.motionScale; easing.type: Easing.OutCubic }
                NumberAnimation { target: animatedContent; property: "blur"; to: 0; duration: 100 * root.motionScale }
            }
            transform: Translate { id: slide }
            // Page title, top left; detail pages get a way back to their parent.
            RowLayout {
                x: root.padding - (backButton.visible ? 8 : 0); y: 12; width: parent.width - root.padding * 2; height: 28
                visible: (root.expanded || root.previewOpen) && !root.ownHeader
                spacing: 2
                IslandButton {
                    id: backButton
                    visible: root.expanded && !!root.parentPage(root.page)
                    iconName: "chevron_left"; implicitHeight: 28; leftPadding: 2; rightPadding: 2
                    Accessible.name: qsTr("Back")
                    onClicked: root.openPage(root.parentPage(root.page))
                }
                IslandText { Layout.fillWidth: true; text: ({ info: qsTr("Info"), clipboard: qsTr("Clipboard"), notifications: qsTr("Notifications"), workspaces: qsTr("Windows"), power: qsTr("Power"), weather: qsTr("Weather"), shelf: qsTr("Shelf") })[root.page] ?? ""; font.pixelSize: 15; font.weight: Font.DemiBold }
            }
            Loader {
                id: pane
                x: (parent.width - width) / 2; y: root.contentY
                width: Math.max(0, Math.min(root.screen.width - 32, root.pageWidth) - root.padding * 2)
                height: root.paneHeight
                active: root.expanded || root.previewOpen || releaseDelay.running
                visible: active
                enabled: root.expanded || root.previewOpen
                sourceComponent: ({ wifi: wifiPane, bluetooth: bluetoothPane, timer: timerPane, glance: glancePane, weather: weatherPane, clipboard: clipboardPane, shelf: shelfPane, media: mediaPane, info: infoPane, more: morePane, controls: controlsPane, notifications: notificationsPane, power: powerPane })[root.page] ?? workspacePane
            }
            // Page dots: the current page is a short bar; any dot jumps to its page.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.contentY + root.paneHeight + 6
                visible: root.inCarousel
                spacing: 0
                Repeater {
                    model: root.carousel
                    Item {
                        id: dot
                        required property string modelData
                        required property int index
                        readonly property bool current: index === root.carouselIndex
                        width: bar.width + 5; height: 14
                        Accessible.role: Accessible.Button
                        Accessible.name: ({ controls: qsTr("Controls"), media: qsTr("Media"), timer: qsTr("Timer"), shelf: qsTr("Shelf"), clipboard: qsTr("Clipboard"), workspaces: qsTr("Windows"), more: qsTr("More") })[modelData] ?? modelData
                        Rectangle {
                            id: bar
                            anchors.centerIn: parent
                            width: dot.current ? 15 : 4; height: 4; radius: 2
                            color: dot.current ? IslandTheme.palette.m3onSurface : dotHover.hovered ? IslandTheme.palette.m3onSurfaceVariant : IslandTheme.palette.handle
                            Behavior on width { enabled: root.motionScale > 0; IslandSpring { motionScale: root.motionScale } }
                            Behavior on color { ColorAnimation { duration: 160 * root.motionScale } }
                        }
                        HoverHandler { id: dotHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.openPage(dot.modelData) }
                    }
                }
            }
            Component { id: controlsPane; IslandControlsView { screen: root.screen; onPageRequested: page => root.openPage(page); onDetailRequested: section => root.toggleDetail(section); onCloseRequested: root.close() } }
            Component { id: morePane; IslandMoreView { screen: root.screen; onPageRequested: page => root.openPage(page) } }
            Component { id: workspacePane; IslandWorkspacesView { screen: root.screen; interactiveFocus: root.expanded; layoutTargetWidth: Math.min(root.screen.width - 32, 744) - 40; onCloseRequested: root.close() } }
            Component { id: wifiPane; IslandWifiView { onBackRequested: root.openPage("controls"); onCloseRequested: root.close() } }
            Component { id: bluetoothPane; IslandBluetoothView { onBackRequested: root.openPage("controls"); onCloseRequested: root.close() } }
            Component { id: timerPane; IslandTimerView {} }
            Component { id: weatherPane; IslandWeatherView { onPageRequested: page => root.openPage(page) } }
            Component { id: notificationsPane; IslandNotificationsView { screenState: root.screenState } }
            Component { id: powerPane; IslandPowerView { onCloseRequested: root.close() } }
            Component { id: mediaPane; IslandMediaView { onPageRequested: page => root.openPage(page) } }
            Component { id: infoPane; IslandInfoView { screenState: root.screenState; onPageRequested: page => root.openPage(page) } }
            Component { id: clipboardPane; IslandClipboardView { onCloseRequested: root.close() } }
            Component { id: glancePane; IslandGlanceView {} }
            Component { id: shelfPane; IslandShelfView { dropActive: root.fileDragOver; onCloseRequested: root.close() } }
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
    // Two-finger swipe (or a sideways wheel) turns carousel pages. It sits
    // above the pages so sliders and lists cannot swallow it; vertical
    // scrolling passes through to whatever is underneath. One swipe turns one
    // page: the gesture locks until the touchpad goes quiet.
    MouseArea {
        id: swipe
        property real travel
        property bool spent
        anchors.fill: parent
        enabled: root.inCarousel
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const dx = wheel.pixelDelta.x || wheel.angleDelta.x / 1.5;
            const dy = wheel.pixelDelta.y || wheel.angleDelta.y / 1.5;
            if (Math.abs(dx) <= Math.abs(dy)) { wheel.accepted = false; return; }
            swipeEnd.restart();
            travel += wheel.inverted ? -dx : dx;
            // Swiping left turns to the next page, right to the previous one
            // (tuned by hand on the touchpad; flip the sign here if reversed).
            if (!spent && Math.abs(travel) > 60) {
                spent = true;
                root.stepPage(travel > 0 ? -1 : 1);
            }
        }
        Timer { id: swipeEnd; interval: 220; onTriggered: { swipe.travel = 0; swipe.spent = false; } }
    }
}
