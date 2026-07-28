pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

StyledWindow {
    id: root

    required property LazyLoader loader

    readonly property var workspaces: {
        const normal = Hypr.workspaces.values.filter(workspace => root.isNormalWorkspace(workspace));
        const active = Hypr.focusedWorkspace;
        if (root.isNormalWorkspace(active) && !normal.includes(active))
            normal.push(active);
        return normal.sort((a, b) => a.id - b.id);
    }
    readonly property var windows: Hypr.toplevels.values.filter(client => root.isNormalWindow(client)).sort((a, b) => {
        const workspaceDelta = (a.workspace?.id ?? 0) - (b.workspace?.id ?? 0);
        if (workspaceDelta)
            return workspaceDelta;

        const aFocus = a.lastIpcObject?.focusHistoryID ?? 0;
        const bFocus = b.lastIpcObject?.focusHistoryID ?? 0;
        return aFocus - bFocus;
    })
    readonly property bool captureEnabled: !loader.closing
    readonly property int gridSpacing: content.Tokens.spacing.large
    readonly property int outerPadding: Math.max(content.Tokens.padding.extraLargeIncreased, Math.round(width * 0.025))
    readonly property int workspaceColumns: {
        const count = workspaces.length;
        if (count < 2)
            return 1;

        const available = Math.max(1, workspaceView.width - outerPadding * 2);
        const preferredWidth = count > 6 ? 380 : 500;
        return Math.max(1, Math.min(count, Math.floor((available + gridSpacing) / (preferredWidth + gridSpacing))));
    }
    readonly property real workspaceCardWidth: {
        const available = Math.max(1, workspaceView.width - outerPadding * 2 - gridSpacing * (workspaceColumns - 1));
        return Math.max(280, Math.min(680, available / workspaceColumns));
    }
    readonly property real workspaceCardHeight: workspaceCardWidth * 0.57

    property string selectedAddress
    property list<var> windowCards: []
    property list<int> workspaceIds: []
    property list<string> windowAddresses: []
    property var previewWarnings: ({})

    function isNormalWorkspace(workspace: var): bool {
        return !!workspace && workspace.id > 0 && !workspace.name.startsWith("special:");
    }

    function isNormalWindow(client: var): bool {
        if (!client || !isNormalWorkspace(client.workspace))
            return false;

        const ipc = client.lastIpcObject ?? {};
        if (ipc.mapped === false || ipc.hidden === true)
            return false;

        const appId = (ipc.class ?? client.wayland?.appId ?? "").toLowerCase();
        return appId !== "org.quickshell" && !appId.startsWith("caelestia-overview");
    }

    function addressOf(client: var): string {
        return client?.address ?? "";
    }

    function workspaceForId(id: int): HyprlandWorkspace {
        return workspaces.find(workspace => workspace.id === id) ?? null;
    }

    function windowForAddress(address: string): HyprlandToplevel {
        return windows.find(client => addressOf(client) === address) ?? null;
    }

    function syncDelegateKeys(): void {
        const nextWorkspaceIds = workspaceIds.slice();
        for (const workspace of workspaces) {
            if (!nextWorkspaceIds.includes(workspace.id))
                nextWorkspaceIds.push(workspace.id);
        }
        if (nextWorkspaceIds.length !== workspaceIds.length)
            workspaceIds = nextWorkspaceIds.sort((a, b) => a - b);

        const nextWindowAddresses = windowAddresses.slice();
        for (const client of windows) {
            const address = addressOf(client);
            if (address && !nextWindowAddresses.includes(address))
                nextWindowAddresses.push(address);
        }
        if (nextWindowAddresses.length !== windowAddresses.length)
            windowAddresses = nextWindowAddresses;
    }

    function registerWindowCard(card: var): void {
        const cards = windowCards.slice();
        cards.push(card);
        windowCards = cards;
    }

    function unregisterWindowCard(card: var): void {
        windowCards = windowCards.filter(item => item !== card);
    }

    function warnPreview(client: var, reason: string): void {
        const key = addressOf(client) || client?.title || "unknown";
        if (previewWarnings[key])
            return;

        previewWarnings[key] = true;
        console.warn(lc, `Falling back to an application card for "${client?.title ?? key}": ${reason}`);
    }

    function reconcileSelection(): void {
        if (windows.length === 0) {
            selectedAddress = "";
            return;
        }

        if (windows.some(client => addressOf(client) === selectedAddress))
            return;

        const active = windows.find(client => client === Hypr.activeToplevel || client.activated);
        selectedAddress = addressOf(active ?? windows[0]);
    }

    function selectRelative(delta: int): void {
        if (windows.length === 0)
            return;

        let index = windows.findIndex(client => addressOf(client) === selectedAddress);
        if (index < 0)
            index = delta > 0 ? -1 : 0;
        index = (index + delta + windows.length) % windows.length;
        selectedAddress = addressOf(windows[index]);
        revealSelection();
    }

    function selectSpatial(direction: string): void {
        const cards = windowCards.filter(card => card.visible && card.width > 0 && card.height > 0);
        if (cards.length === 0)
            return;

        let current = cards.find(card => addressOf(card.client) === selectedAddress);
        if (!current) {
            selectedAddress = addressOf(cards[0].client);
            revealSelection();
            return;
        }

        const origin = current.mapToItem(content, current.width / 2, current.height / 2);
        let best = null;
        let bestScore = Number.POSITIVE_INFINITY;

        for (const candidate of cards) {
            if (candidate === current)
                continue;

            const point = candidate.mapToItem(content, candidate.width / 2, candidate.height / 2);
            const dx = point.x - origin.x;
            const dy = point.y - origin.y;
            const horizontal = direction === "left" || direction === "right";
            const primary = horizontal ? dx : dy;
            const perpendicular = horizontal ? Math.abs(dy) : Math.abs(dx);
            const valid = (direction === "left" || direction === "up") ? primary < -1 : primary > 1;
            if (!valid)
                continue;

            const score = Math.abs(primary) + perpendicular * 0.38;
            if (score < bestScore) {
                best = candidate;
                bestScore = score;
            }
        }

        if (best) {
            selectedAddress = addressOf(best.client);
            revealSelection();
        }
    }

    function revealSelection(): void {
        Qt.callLater(() => {
            const card = windowCards.find(item => addressOf(item.client) === selectedAddress);
            if (!card)
                return;

            const point = card.mapToItem(workspaceView, 0, 0);
            if (point.y < outerPadding)
                workspaceView.contentY = Math.max(0, workspaceView.contentY + point.y - outerPadding);
            else if (point.y + card.height > workspaceView.height - outerPadding)
                workspaceView.contentY = Math.max(0, Math.min(Math.max(0, workspaceView.contentHeight - workspaceView.height),
                    workspaceView.contentY + point.y + card.height - workspaceView.height + outerPadding));
        });
    }

    function activateWorkspace(workspace: var): void {
        if (!isNormalWorkspace(workspace)) {
            console.warn(lc, "Refusing to activate an invalid workspace from the overview");
            return;
        }

        close();
        workspace.activate();
    }

    function activateWindow(client: var): void {
        if (!client || !windows.includes(client)) {
            console.warn(lc, "Unable to activate a window that is no longer present in the overview");
            reconcileSelection();
            return;
        }

        const workspace = client.workspace;
        const waylandToplevel = client.wayland;
        close();

        if (isNormalWorkspace(workspace) && !workspace.focused)
            workspace.activate();

        if (waylandToplevel) {
            waylandToplevel.activate();
            return;
        }

        const rawAddress = addressOf(client);
        if (!rawAddress) {
            console.warn(lc, `Unable to activate "${client.title}": no Wayland toplevel or Hyprland address is available`);
            return;
        }

        const address = rawAddress.startsWith("0x") ? rawAddress : `0x${rawAddress}`;
        const selector = `address:${address}`;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "${selector}" })` : `focuswindow ${selector}`);
    }

    function activateSelected(): void {
        const client = windows.find(item => addressOf(item) === selectedAddress);
        if (client)
            activateWindow(client);
    }

    function close(): void {
        if (!loader.closing)
            closeAnimation.start();
    }

    onWorkspacesChanged: syncDelegateKeys()
    onWindowsChanged: {
        syncDelegateKeys();
        Qt.callLater(reconcileSelection);
    }

    Component.onCompleted: syncDelegateKeys()

    name: "workspace-overview"
    color: "transparent"
    surfaceFormat.opaque: false

    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: loader.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    mask: loader.closing ? emptyRegion : null

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Region {
        id: emptyRegion
    }

    SequentialAnimation {
        id: closeAnimation

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        ParallelAnimation {
            Anim {
                target: content
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            Anim {
                target: content
                property: "scale"
                to: 0.97
                type: Anim.StandardLarge
            }
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    FocusScope {
        id: content

        anchors.fill: parent
        focus: true
        opacity: 0
        scale: 0.97

        Component.onCompleted: {
            root.loader.closing = false;
            root.reconcileSelection();
            forceActiveFocus();
            opacity = 1;
            scale = 1;
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close();
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                const backwards = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier);
                root.selectRelative(backwards ? -1 : 1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activateSelected();
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const workspaceId = event.key - Qt.Key_0;
                const workspace = root.workspaces.find(item => item.id === workspaceId);
                if (workspace)
                    root.activateWorkspace(workspace);
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                root.selectSpatial("left");
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                root.selectSpatial("right");
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.selectSpatial("up");
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.selectSpatial("down");
            } else {
                return;
            }
            event.accepted = true;
        }

        Behavior on opacity {
            Anim {
                type: Anim.StandardLarge
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.StandardLarge
            }
        }

        StyledRect {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim, 0.78)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: root.outerPadding
            anchors.leftMargin: root.outerPadding
            anchors.rightMargin: root.outerPadding
            spacing: Tokens.spacing.large

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.medium
                Layout.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.large

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: qsTr("Workspaces")
                        font: Tokens.font.body.builders.large.size(30).weight(Font.DemiBold).build()
                    }

                    StyledText {
                        text: qsTr("%1 workspace%2 · %3 window%4").arg(root.workspaces.length)
                            .arg(root.workspaces.length === 1 ? "" : "s")
                            .arg(root.windows.length)
                            .arg(root.windows.length === 1 ? "" : "s")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.width >= 1000
                    text: qsTr("Tab / arrows to navigate   ·   Enter to open   ·   Esc to close")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }

                StyledRect {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: closeIcon.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: closeIcon.implicitHeight + Tokens.padding.large
                    radius: Tokens.rounding.full
                    color: Colours.tPalette.m3surfaceContainerHigh

                    StateLayer {
                        radius: parent.radius
                        onClicked: root.close()
                    }

                    MaterialIcon {
                        id: closeIcon

                        anchors.centerIn: parent
                        text: "close"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.large
                    }
                }
            }

            StyledFlickable {
                id: workspaceView

                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                contentWidth: width
                contentHeight: workspaceGrid.implicitHeight + root.outerPadding * 2
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                GridLayout {
                    id: workspaceGrid

                    x: Math.round((workspaceView.width - implicitWidth) / 2)
                    y: root.outerPadding
                    columns: root.workspaceColumns
                    columnSpacing: root.gridSpacing
                    rowSpacing: root.gridSpacing

                    Repeater {
                        // Keep primitive keys until this overview instance is unloaded. Removing
                        // a live Hyprland QObject from a Repeater can otherwise invalidate
                        // modelData while the animated delegate is still handling notifications.
                        model: root.workspaceIds

                        WorkspaceCard {
                            required property int modelData

                            Layout.preferredWidth: visible ? root.workspaceCardWidth : 0
                            Layout.preferredHeight: visible ? root.workspaceCardHeight : 0

                            workspaceId: modelData
                            overview: root
                        }
                    }
                }
            }
        }
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.overview"
        defaultLogLevel: LoggingCategory.Info
    }
}
