pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Scope {
    id: root

    readonly property var screenNames: Screens.screens.map(screen => screen.name)
    readonly property bool blurEnabled: Colours.transparency.enabled
    readonly property real blurAlpha: Colours.transparency.base
    readonly property alias service: usageService

    property string openScreenName
    property var renderingScreens: []

    function screenForName(name: string): ShellScreen {
        return Screens.screens.find(screen => screen.name === name) ?? null;
    }

    function focusedScreenName(): string {
        const focused = Hypr.focusedMonitor;
        for (const screen of Screens.screens)
            if (Hypr.monitorFor(screen) === focused)
                return screen.name;
        return Screens.screens[0]?.name ?? "";
    }

    function screenHasFullscreen(name: string): bool {
        const screen = screenForName(name);
        if (!screen)
            return true;

        const monitor = Hypr.monitorFor(screen);
        if (!monitor)
            return false;

        const specialName = monitor.lastIpcObject?.specialWorkspace?.name ?? "";
        if (specialName) {
            const special = Hypr.workspaces.values.find(workspace => workspace.name === specialName);
            return special?.toplevels.values.some(toplevel => (toplevel.lastIpcObject?.fullscreen ?? 0) > 1) ?? false;
        }
        return monitor.activeWorkspace?.toplevels.values.some(toplevel => (toplevel.lastIpcObject?.fullscreen ?? 0) > 1) ?? false;
    }

    function requestOpen(name: string): void {
        if (screenNames.includes(name) && !screenHasFullscreen(name)) {
            usageService.refreshIfStale();
            openScreenName = name;
        }
    }

    function requestClose(name: string): void {
        if (!name || openScreenName === name)
            openScreenName = "";
    }

    function setRendering(name: string, rendering: bool): void {
        const next = renderingScreens.filter(screenName => screenName !== name);
        if (rendering && screenNames.includes(name))
            next.push(name);
        renderingScreens = next;
    }

    function refreshLayerRules(): void {
        let blurRule;
        let alphaRule;
        if (Hypr.usingLua) {
            blurRule = `eval hl.layer_rule({ match = { namespace = "caelestia-aiusage" }, blur = ${blurEnabled} })`;
            alphaRule = `eval hl.layer_rule({ match = { namespace = "caelestia-aiusage" }, ignore_alpha = ${Math.max(0, blurAlpha - 0.03)} })`;
        } else {
            blurRule = `keyword layerrule blur ${blurEnabled ? 1 : 0}, match:namespace caelestia-aiusage`;
            alphaRule = `keyword layerrule ignore_alpha ${Math.max(0, blurAlpha - 0.03)}, match:namespace caelestia-aiusage`;
        }
        Hypr.extras.batchMessage([blurRule, alphaRule]);
    }

    onScreenNamesChanged: {
        if (openScreenName && !screenNames.includes(openScreenName))
            openScreenName = "";
        renderingScreens = renderingScreens.filter(name => screenNames.includes(name));
    }
    onBlurEnabledChanged: layerRuleDebounce.restart()
    onBlurAlphaChanged: layerRuleDebounce.restart()

    Component.onCompleted: refreshLayerRules()
    Component.onDestruction: {
        openScreenName = "";
        renderingScreens = [];
        layerRuleDebounce.stop();
    }

    AiUsageService {
        id: usageService
    }

    Variants {
        model: root.screenNames

        AiUsageWindow {
            required property string modelData

            controller: root
            screenName: modelData
            screen: root.screenForName(modelData)
        }
    }

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.refreshLayerRules();
        }
    }

    Timer {
        id: layerRuleDebounce

        interval: 30
        onTriggered: root.refreshLayerRules()
    }

    IpcHandler {
        function open(screen: string): string {
            const target = screen || root.focusedScreenName();
            root.requestOpen(target);
            return root.openScreenName;
        }

        function close(): void {
            root.requestClose(root.openScreenName);
        }

        function toggle(screen: string): string {
            const target = screen || root.focusedScreenName();
            if (root.openScreenName === target)
                root.requestClose(target);
            else
                root.requestOpen(target);
            return root.openScreenName;
        }

        function refresh(): void {
            usageService.refreshCodex(true);
        }

        function status(): string {
            return JSON.stringify({
                openScreen: root.openScreenName,
                renderingScreens: root.renderingScreens,
                codex: {
                    available: usageService.codex.available,
                    loading: usageService.codex.loading,
                    stale: usageService.codex.stale,
                    plan: usageService.codex.plan,
                    quotas: usageService.codex.quotas,
                    updatedAt: usageService.codex.updatedAt,
                    resetCreditsAvailable: usageService.codex.resetCreditsAvailable,
                    error: usageService.codex.error
                },
                antigravity: {
                    available: usageService.antigravity.available,
                    loading: usageService.antigravity.loading,
                    stale: usageService.antigravity.stale,
                    plan: usageService.antigravity.plan,
                    quotas: usageService.antigravity.quotas,
                    updatedAt: usageService.antigravity.updatedAt,
                    error: usageService.antigravity.error
                }
            });
        }

        target: "aiUsage"
    }
}
