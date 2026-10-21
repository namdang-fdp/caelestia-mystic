pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root
    required property ScreenState screenState
    required property ShellScreen screen
    property bool fullscreen
    property bool previewOpen
    property bool notificationExpanded
    property bool wifiOpen
    property bool bluetoothOpen
    property string lastDetail: ""
    property string detailSection: "wifi"
    property string transientIcon
    property string transientText
    property bool feedbackReady
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property real motionScale: Tokens.anim.durations.scale
    readonly property bool expanded: screenState.dashboard && Config.dashboard.enabled
    readonly property string previewPage: compact.hasMedia ? "media" : "controls"
    readonly property string page: previewOpen ? previewPage : screenState.islandPage === "media" && !Config.dashboard.showMedia ? "controls" : screenState.islandPage
    readonly property var pending: Notifs.popups.filter(n => !n.closed && (n.popupScreenName === screen.name || !Quickshell.screens.some(s => s.name === n.popupScreenName) && ShellState.forActive() === screenState))
    readonly property var foreground: pending.length ? pending[pending.length - 1] : null
    readonly property bool showingToast: !!foreground && !expanded
    readonly property bool showingFeedback: feedbackTimer.running && !expanded && !showingToast && !previewOpen
    readonly property string mode: expanded ? page : showingToast ? "notification" : previewOpen ? "peek" : showingFeedback ? "feedback" : "compact"
    readonly property bool previewAllowed: Config.dashboard.enabled && Config.dashboard.showOnHover && !fullscreen
    readonly property bool interactionHovered: hover.hovered || (wifiLoader.item?.hovered ?? false) || (bluetoothLoader.item?.hovered ?? false)
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
    readonly property bool basicPage: page === "controls" || page === "media"
    readonly property real contentY: basicPage ? 14 : 46
    readonly property real padding: basicPage ? 16 : 20
    readonly property bool inlineDetails: screen.width < 1100
    readonly property alias wifiPanel: wifiLoader
    readonly property alias bluetoothPanel: bluetoothLoader
    readonly property real paneHeight: pane.item?.implicitHeight ?? (page === "controls" ? 286 : page === "media" ? 188 : 304)
    readonly property real pageWidth: ({ controls: 424, media: 400, more: 448, info: 540, clipboard: 520, notifications: 480, workspaces: 744, power: 400, connections: 360 })[page] ?? 424
    readonly property real targetWidth: expanded || previewOpen ? pageWidth : showingToast ? notificationExpanded ? 480 : 360 : showingFeedback ? 280 : compact.implicitWidth
    readonly property real targetHeight: expanded || previewOpen ? paneHeight + contentY + 16 : showingToast ? notification.itemAt(0)?.implicitHeight ?? 76 : showingFeedback ? 40 : 36
    implicitWidth: Math.min(screen.width - 32, targetWidth)
    implicitHeight: Math.min(screen.height - 32, targetHeight)
    visible: Config.dashboard.enabled && (!fullscreen || expanded || WindowUx.resizing) || !!foreground
    anchors.topMargin: 8

    function openPage(name: string): void {
        if (!Config.dashboard.enabled) return;
        previewOpen = false;
        screenState.launcher = false;
        screenState.islandPage = name === "media" && !Config.dashboard.showMedia ? "controls" : name;
        screenState.dashboard = true;
    }
    function toggleDetail(section: string): void {
        detailSection = section;
        if (inlineDetails) { openPage("connections"); return; }
        if (!expanded || page !== "controls") openPage("controls");
        if (section === "wifi") wifiOpen = !wifiOpen;
        else bluetoothOpen = !bluetoothOpen;
        lastDetail = section;
    }
    function close(): void {
        wifiOpen = false; bluetoothOpen = false;
        screenState.dashboard = false;
        previewOpen = false;
        enterDelay.stop();
    }
    function closeTop(): void {
        if (lastDetail === "bluetooth" && bluetoothOpen) bluetoothOpen = false;
        else if (wifiOpen) wifiOpen = false;
        else if (bluetoothOpen) bluetoothOpen = false;
        else close();
    }
    function feedback(iconName: string, text: string): void {
        if (!feedbackReady || fullscreen || !Config.dashboard.enabled || Hypr.focusedMonitor !== monitor || expanded || showingToast) return;
        transientIcon = iconName; transientText = text;
        feedbackTimer.restart();
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
        else { wifiOpen = false; bluetoothOpen = false; if (pane.active) releaseDelay.restart(); }
    }
    onPreviewAllowedChanged: if (!previewAllowed) previewOpen = false
    onShowingToastChanged: { previewOpen = false; enterDelay.stop(); }
    onVisibleChanged: if (!visible) previewOpen = false
    onPageChanged: {
        contentExit.stop(); contentFade.restart();
        if (page !== "controls") { wifiOpen = false; bluetoothOpen = false; }
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
        border.color: Qt.alpha("white", root.expanded || root.previewOpen ? .1 : .06)
        Behavior on radius { NumberAnimation { duration: 380 * root.motionScale; easing.type: Easing.OutCubic } }
    }
    HoverHandler {
        id: hover
        cursorShape: root.expanded || root.previewOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered && root.previewAllowed && !root.expanded && !root.showingToast) enterDelay.restart();
        }
    }
    Timer { id: enterDelay; interval: 260; onTriggered: if (hover.hovered && root.previewAllowed && !root.expanded && !root.showingToast) root.previewOpen = true }
    Timer { id: leaveDelay; interval: 300; onTriggered: if (!root.interactionHovered && !root.dragging && !root.nativeMenuOpen) root.previewOpen = false }
    Timer { id: releaseDelay; interval: Math.max(1, 420 * root.motionScale) }
    Timer { id: feedbackTimer; interval: 1400 }
    Timer { id: feedbackWarmup; interval: 800; onTriggered: root.feedbackReady = true }
    Connections {
        target: Audio
        function onVolumeChanged(): void { root.feedback("volume_up", qsTr("Volume · %1%").arg(Math.round(Audio.volume * 100))); }
        function onMutedChanged(): void { root.feedback(Audio.muted ? "volume_off" : "volume_up", Audio.muted ? qsTr("Muted") : qsTr("Sound on")); }
    }
    Connections {
        target: root.monitor
        function onActiveWorkspaceChanged(): void { root.feedback("grid_view", qsTr("Workspace %1").arg(root.monitor?.activeWorkspace?.id ?? 1)); }
    }
    Connections {
        target: Brightness.getMonitorForScreen(root.screen)
        function onBrightnessChanged(): void { root.feedback("brightness_6", qsTr("Brightness · %1%").arg(Math.round(Brightness.getMonitorForScreen(root.screen).brightness * 100))); }
    }
    TapHandler {
        enabled: !root.expanded && !root.showingToast
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onTapped: (point, button) => root.openPage(button === Qt.RightButton ? "controls" : button === Qt.MiddleButton ? "workspaces" : compact.hasMedia ? "media" : "controls")
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
        Row {
            anchors.centerIn: parent
            spacing: 8
            visible: root.showingFeedback
            IslandText { text: Time.timeStr; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 1; height: 14; color: "#4a4d52"; anchors.verticalCenter: parent.verticalCenter }
            MaterialIcon { text: root.transientIcon; color: IslandTheme.palette.m3primary; fontStyle: Tokens.font.icon.small; anchors.verticalCenter: parent.verticalCenter }
            IslandText { text: root.transientText; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
        }
        Item {
            id: animatedContent
            anchors.fill: parent
            SequentialAnimation {
                id: contentFade
                PropertyAction { target: animatedContent; property: "opacity"; value: 0 }
                PauseAnimation { duration: 70 * root.motionScale }
                NumberAnimation { target: animatedContent; property: "opacity"; to: 1; duration: 210 * root.motionScale; easing.type: Easing.OutCubic }
            }
            NumberAnimation { id: contentExit; target: animatedContent; property: "opacity"; to: 0; duration: 100 * root.motionScale; easing.type: Easing.OutCubic }
            RowLayout {
                x: 12; y: 8; width: parent.width - 24; height: 30
                visible: (root.expanded || root.previewOpen) && !root.basicPage
                IslandButton { iconName: "chevron_left"; implicitHeight: 28; leftPadding: 4; rightPadding: 4; Accessible.name: qsTr("Back to Control Center"); onClicked: root.openPage("controls") }
                IslandText { Layout.fillWidth: true; text: ({ more: qsTr("Controls"), info: qsTr("Info"), clipboard: qsTr("Clipboard"), notifications: qsTr("Notifications"), workspaces: qsTr("Windows"), power: qsTr("Power"), connections: qsTr("Connections") })[root.page] ?? ""; font.pixelSize: 12; color: IslandTheme.palette.m3onSurfaceVariant }
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
                sourceComponent: root.page === "connections" ? connectionsPane : root.page === "clipboard" ? clipboardPane : root.page === "media" ? mediaPane : root.page === "info" ? infoPane : root.page === "more" ? morePane : root.page === "controls" ? controlsPane : root.page === "notifications" ? notificationsPane : root.page === "power" ? powerPane : workspacePane
            }
            Component { id: controlsPane; IslandControlsView { screen: root.screen; onPageRequested: page => root.openPage(page); onDetailRequested: section => root.toggleDetail(section); onCloseRequested: root.close() } }
            Component { id: morePane; IslandMoreView { screen: root.screen; onPageRequested: page => root.openPage(page) } }
            Component { id: workspacePane; IslandWorkspacesView { screen: root.screen; interactiveFocus: root.expanded; layoutTargetWidth: Math.min(root.screen.width - 32, 744) - 40; onCloseRequested: root.close() } }
            Component { id: connectionsPane; IslandConnectionsView { section: root.detailSection; onCloseRequested: root.openPage("controls") } }
            Component { id: notificationsPane; IslandNotificationsView { screenState: root.screenState } }
            Component { id: powerPane; IslandPowerView { onCloseRequested: root.close() } }
            Component { id: mediaPane; IslandMediaView { onPageRequested: page => root.openPage(page) } }
            Component { id: infoPane; IslandInfoView { screenState: root.screenState } }
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
    Loader {
        id: wifiLoader
        active: root.expanded && root.page === "controls" && root.wifiOpen && !root.inlineDetails
        visible: active && root.visible
        x: -width - 12
        width: 300; height: Math.min(root.screen.height - 24, item?.implicitHeight ?? 210)
        sourceComponent: IslandConnectionPanel { section: "wifi"; onCloseRequested: root.wifiOpen = false }
    }
    Loader {
        id: bluetoothLoader
        active: root.expanded && root.page === "controls" && root.bluetoothOpen && !root.inlineDetails
        visible: active && root.visible
        x: root.width + 12
        width: 300; height: Math.min(root.screen.height - 24, item?.implicitHeight ?? 210)
        sourceComponent: IslandConnectionPanel { section: "bluetooth"; onCloseRequested: root.bluetoothOpen = false }
    }
}
