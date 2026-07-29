pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia
import qs.components.misc
import qs.services
import qs.utils

Scope {
    id: root

    readonly property string laptopConnector: "eDP-1"
    readonly property string externalConnector: "HDMI-A-1"
    readonly property list<string> validProfiles: ["auto", "home-dual", "laptop-only", "external-only"]

    property var monitorSnapshots: []
    property var lastKnownMonitors: ({})
    property string topologySignature
    property int topologyGeneration

    property string profileMode: "auto"
    property string selectedProfile: "auto"
    property string lastAppliedProfile
    property string lastTopologySignature
    property bool stateLoaded
    property bool startupHandled

    property bool applying
    property string operationStage
    property int operationGeneration
    property var operationPlan: null
    property string operationRequestedProfile
    property string operationSource
    property bool operationChangesSelection

    property string topologyPurpose
    property string queuedTopologyPurpose
    property string lastPolicyKey
    property string lastToastKey
    property double lastToastTime

    property ShellScreen targetScreen
    property var overlaySnapshots: []

    function profileLabel(profile: string): string {
        switch (profile) {
        case "auto":
            return qsTr("Auto");
        case "home-dual":
            return qsTr("Home Dual");
        case "laptop-only":
            return qsTr("Laptop Only");
        case "external-only":
            return qsTr("External Only");
        default:
            return profile;
        }
    }

    function cloneSnapshots(snapshots: var): var {
        return snapshots.map(snapshot => Object.assign({}, snapshot));
    }

    function monitorNamed(name: string, snapshots = monitorSnapshots): var {
        return snapshots.find(snapshot => snapshot.name === name) ?? null;
    }

    function hasMonitor(name: string, snapshots = monitorSnapshots): bool {
        return monitorNamed(name, snapshots) !== null;
    }

    function validScale(value: var): real {
        const scale = Number(value);
        return isFinite(scale) && scale > 0 ? scale : 1;
    }

    function preferredSize(monitor: var): var {
        const modes = monitor.availableModes ?? [];
        if (modes.length > 0) {
            const match = String(modes[0]).match(/^(\d+)x(\d+)/);
            if (match)
                return {
                    width: Number(match[1]),
                    height: Number(match[2])
                };
        }
        return {
            width: Math.max(1, Number(monitor.width) || 1),
            height: Math.max(1, Number(monitor.height) || 1)
        };
    }

    function normaliseMonitor(raw: var): var {
        const name = String(raw.name ?? "");
        const previous = lastKnownMonitors[name] ?? {};
        const modes = Array.isArray(raw.availableModes) ? raw.availableModes.slice() : (previous.availableModes ?? []);
        const rawWidth = Number(raw.width);
        const rawHeight = Number(raw.height);
        const rawRefresh = Number(raw.refreshRate);
        const rawScale = Number(raw.scale);
        const snapshot = {
            name,
            description: String(raw.description ?? previous.description ?? ""),
            width: rawWidth > 0 ? rawWidth : (previous.width ?? 0),
            height: rawHeight > 0 ? rawHeight : (previous.height ?? 0),
            refreshRate: rawRefresh > 0 ? rawRefresh : (previous.refreshRate ?? 0),
            x: Number.isFinite(Number(raw.x)) ? Number(raw.x) : (previous.x ?? 0),
            y: Number.isFinite(Number(raw.y)) ? Number(raw.y) : (previous.y ?? 0),
            scale: rawScale > 0 && isFinite(rawScale) ? rawScale : validScale(previous.scale),
            enabled: raw.disabled !== true,
            connected: true,
            availableModes: modes
        };
        lastKnownMonitors[name] = Object.assign({}, snapshot);
        return snapshot;
    }

    function updateTopology(rawMonitors: var): void {
        const snapshots = rawMonitors
            .filter(monitor => monitor && monitor.name)
            .map(monitor => normaliseMonitor(monitor))
            .sort((a, b) => a.name.localeCompare(b.name));
        const signature = snapshots.map(monitor => monitor.name).join("|");

        if (signature !== topologySignature) {
            topologySignature = signature;
            topologyGeneration++;
            lastPolicyKey = "";
        }
        monitorSnapshots = snapshots;
    }

    function resolveAuto(snapshots = monitorSnapshots): string {
        if (hasMonitor(externalConnector, snapshots) && hasMonitor(laptopConnector, snapshots))
            return "home-dual";
        if (hasMonitor(laptopConnector, snapshots))
            return "laptop-only";
        return "";
    }

    function makePlan(profile: string, snapshots = monitorSnapshots): var {
        const resolved = profile === "auto" ? resolveAuto(snapshots) : profile;
        const laptop = monitorNamed(laptopConnector, snapshots);
        const external = monitorNamed(externalConnector, snapshots);

        if (!resolved)
            return {
                error: qsTr("No supported laptop topology is currently available")
            };

        if (resolved === "home-dual") {
            if (!laptop || !external)
                return {
                    error: qsTr("Home Dual requires both %1 and %2").arg(externalConnector).arg(laptopConnector)
                };

            const externalSize = preferredSize(external);
            const laptopSize = preferredSize(laptop);
            const externalScale = validScale(external.scale);
            return {
                profile: resolved,
                enabled: [{
                        name: externalConnector,
                        width: externalSize.width,
                        height: externalSize.height,
                        x: 0,
                        y: 0,
                        scale: externalScale
                    }, {
                        name: laptopConnector,
                        width: laptopSize.width,
                        height: laptopSize.height,
                        x: Math.round(externalSize.width / externalScale),
                        y: 0,
                        scale: validScale(laptop.scale)
                    }],
                disabled: [],
                safetyTarget: "",
                title: qsTr("Home Dual applied"),
                message: qsTr("External left · Laptop right")
            };
        }

        if (resolved === "laptop-only") {
            if (!laptop)
                return {
                    error: qsTr("Laptop Only requires %1").arg(laptopConnector)
                };
            const laptopSize = preferredSize(laptop);
            return {
                profile: resolved,
                enabled: [{
                        name: laptopConnector,
                        width: laptopSize.width,
                        height: laptopSize.height,
                        x: 0,
                        y: 0,
                        scale: validScale(laptop.scale)
                    }],
                disabled: external ? [externalConnector] : [],
                safetyTarget: laptopConnector,
                title: qsTr("Laptop Mode applied"),
                message: qsTr("%1 restored to 0x0").arg(laptopConnector)
            };
        }

        if (resolved === "external-only") {
            if (!external)
                return {
                    error: qsTr("External Only requires %1").arg(externalConnector)
                };
            const externalSize = preferredSize(external);
            return {
                profile: resolved,
                enabled: [{
                        name: externalConnector,
                        width: externalSize.width,
                        height: externalSize.height,
                        x: 0,
                        y: 0,
                        scale: validScale(external.scale)
                    }],
                disabled: laptop ? [laptopConnector] : [],
                safetyTarget: externalConnector,
                title: qsTr("External Mode applied"),
                message: qsTr("%1 active at 0x0").arg(externalConnector)
            };
        }

        return {
            error: qsTr("Unknown monitor profile: %1").arg(profile)
        };
    }

    function profileMatches(plan: var, snapshots = monitorSnapshots): bool {
        if (!plan || plan.error)
            return false;

        for (const desired of plan.enabled) {
            const current = monitorNamed(desired.name, snapshots);
            if (!current || !current.enabled)
                return false;
            if (current.width !== desired.width || current.height !== desired.height)
                return false;
            if (current.x !== desired.x || current.y !== desired.y)
                return false;
            if (Math.abs(validScale(current.scale) - desired.scale) > 0.001)
                return false;
        }

        for (const name of plan.disabled) {
            const current = monitorNamed(name, snapshots);
            if (current && current.enabled)
                return false;
        }
        return true;
    }

    function luaQuote(value: string): string {
        return "\"" + String(value)
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
            .replace(/\r/g, "\\r")
            .replace(/\n/g, "\\n") + "\"";
    }

    function luaNumber(value: real): string {
        const number = Number(value);
        return isFinite(number) ? String(number) : "1";
    }

    function configureLua(plan: var): string {
        const rules = plan.enabled.map(monitor => [
            "hl.monitor({",
            `output = ${luaQuote(monitor.name)},`,
            "mode = \"preferred\",",
            `position = ${luaQuote(`${monitor.x}x${monitor.y}`)},`,
            `scale = ${luaNumber(monitor.scale)},`,
            "disabled = false",
            "})"
        ].join(" "));
        return rules.join("\n");
    }

    function disableLua(plan: var): string {
        const lines = [];
        if (plan.safetyTarget) {
            lines.push(`if not hl.get_monitor(${luaQuote(plan.safetyTarget)}) then error(${luaQuote(`Target monitor ${plan.safetyTarget} disappeared`)}) end`);
        }
        for (const name of plan.disabled)
            lines.push(`hl.monitor({ output = ${luaQuote(name)}, disabled = true })`);
        return lines.join("\n");
    }

    function requestTopologyQuery(purpose: string): void {
        if (topologyProcess.running) {
            if (purpose !== "event" || !queuedTopologyPurpose)
                queuedTopologyPurpose = purpose;
            return;
        }

        topologyPurpose = purpose;
        topologyProcess.exec(["hyprctl", "-j", "monitors", "all"]);
    }

    function runQueuedTopologyQuery(): void {
        if (topologyProcess.running || !queuedTopologyPurpose)
            return;
        const purpose = queuedTopologyPurpose;
        queuedTopologyPurpose = "";
        requestTopologyQuery(purpose);
    }

    function handleTopologyResult(text: string): void {
        const purpose = topologyPurpose;
        topologyPurpose = "";
        let data;
        try {
            data = JSON.parse(text);
            if (!Array.isArray(data))
                throw new Error("Hyprland returned a non-array monitor response");
        } catch (error) {
            if (purpose !== "event")
                failApply(qsTr("Unable to read connected monitors: %1").arg(error));
            else
                console.warn(lc, `Unable to parse monitor topology: ${error}`);
            Qt.callLater(runQueuedTopologyQuery);
            return;
        }

        updateTopology(data);

        if (purpose === "preflight")
            beginApplyAfterPreflight();
        else if (purpose === "verify")
            verifyConfiguredMonitors();
        else if (purpose === "final")
            finishApplyAfterVerification();
        else
            maybeApplyPolicy(purpose);

        Qt.callLater(runQueuedTopologyQuery);
    }

    function scheduleTopologyProbe(): void {
        if (overlayLoader.active)
            forceCloseOverlay();
        topologyDebounce.restart();
    }

    function requestApply(profile: string, source: string, changeSelection: bool): bool {
        if (!validProfiles.includes(profile)) {
            showFailure(qsTr("Unknown monitor profile: %1").arg(profile));
            return false;
        }
        if (applying) {
            if (source === "manual")
                showFailure(qsTr("A monitor profile is already being applied"));
            return false;
        }

        applying = true;
        operationRequestedProfile = profile;
        operationSource = source;
        operationChangesSelection = changeSelection;
        operationStage = "preflight";
        requestTopologyQuery("preflight");
        return true;
    }

    function beginApplyAfterPreflight(): void {
        if (!applying || operationStage !== "preflight")
            return;

        const plan = makePlan(operationRequestedProfile);
        if (plan.error) {
            failApply(plan.error);
            return;
        }

        if (operationSource !== "startup" && profileMatches(plan)) {
            operationPlan = plan;
            completeApply(operationSource === "manual");
            return;
        }

        operationPlan = plan;
        operationGeneration = topologyGeneration;
        operationStage = "configure";
        applyProcess.exec(["hyprctl", "eval", configureLua(plan)]);
    }

    function handleApplyExit(exitCode: int): void {
        if (!applying)
            return;

        if (exitCode !== 0) {
            const detail = applyStderr.text.trim() || applyStdout.text.trim() || qsTr("hyprctl eval failed");
            failApply(detail);
            return;
        }

        if (operationStage === "configure") {
            operationStage = "verify";
            verificationTimer.restart();
        } else if (operationStage === "disable") {
            operationStage = "final";
            verificationTimer.restart();
        }
    }

    function verifyConfiguredMonitors(): void {
        if (!applying || operationStage !== "verify")
            return;
        if (topologyGeneration !== operationGeneration) {
            failApply(qsTr("Monitor topology changed while applying the profile"));
            return;
        }

        for (const desired of operationPlan.enabled) {
            const current = monitorNamed(desired.name);
            if (!current || !current.enabled) {
                failApply(qsTr("%1 did not become active; the existing display was left enabled").arg(desired.name));
                return;
            }
        }

        if (operationPlan.disabled.length === 0) {
            operationStage = "final";
            finishApplyAfterVerification();
            return;
        }

        operationStage = "disable";
        applyProcess.exec(["hyprctl", "eval", disableLua(operationPlan)]);
    }

    function finishApplyAfterVerification(): void {
        if (!applying || operationStage !== "final")
            return;
        if (topologyGeneration !== operationGeneration) {
            failApply(qsTr("Monitor topology changed before the profile finished"));
            return;
        }
        if (!profileMatches(operationPlan)) {
            failApply(qsTr("Hyprland did not reach the requested monitor layout"));
            return;
        }
        completeApply(true);
    }

    function completeApply(showToast: bool): void {
        const plan = operationPlan;
        const requested = operationRequestedProfile;
        const changesSelection = operationChangesSelection;

        applying = false;
        operationStage = "";
        operationPlan = null;

        if (changesSelection) {
            selectedProfile = requested;
            profileMode = requested === "auto" ? "auto" : "manual";
        }
        lastAppliedProfile = plan.profile;
        lastTopologySignature = topologySignature;
        lastPolicyKey = `${profileMode}:${selectedProfile}:${topologySignature}`;
        saveState();

        if (showToast)
            showSuccess(plan.title, plan.message);
    }

    function failApply(message: string): void {
        if (!applying)
            return;
        applying = false;
        operationStage = "";
        operationPlan = null;
        console.warn(lc, `Monitor profile apply failed: ${message}`);
        showFailure(message);
    }

    function showSuccess(title: string, message: string): void {
        const key = `${title}|${message}`;
        const now = Date.now();
        if (key === lastToastKey && now - lastToastTime < 2500)
            return;
        lastToastKey = key;
        lastToastTime = now;
        Toaster.toast(title, message, "desktop_windows", Toast.Success);
    }

    function showFailure(message: string): void {
        const key = `failure|${message}`;
        const now = Date.now();
        if (key === lastToastKey && now - lastToastTime < 2500)
            return;
        lastToastKey = key;
        lastToastTime = now;
        Toaster.toast(qsTr("Monitor profile not applied"), message, "monitor_heart", Toast.Error);
    }

    function maybeApplyPolicy(reason: string): void {
        if (!stateLoaded || applying || monitorSnapshots.length === 0)
            return;

        const isStartup = !startupHandled;
        let requested = profileMode === "auto" ? "auto" : selectedProfile;
        let plan = makePlan(requested);

        if (plan.error && profileMode === "manual" && hasMonitor(laptopConnector) && !hasMonitor(externalConnector)) {
            requested = "laptop-only";
            plan = makePlan(requested);
        }
        if (plan.error) {
            if (isStartup)
                startupHandled = true;
            console.info(lc, `Monitor policy is waiting for a compatible topology: ${plan.error}`);
            return;
        }

        const policyKey = `${profileMode}:${selectedProfile}:${topologySignature}`;
        if (!isStartup && policyKey === lastPolicyKey && profileMatches(plan))
            return;
        if (!isStartup && profileMatches(plan)) {
            const profileChanged = lastAppliedProfile !== plan.profile;
            lastPolicyKey = policyKey;
            lastAppliedProfile = plan.profile;
            lastTopologySignature = topologySignature;
            saveState();
            if (profileChanged)
                showSuccess(plan.title, plan.message);
            return;
        }

        startupHandled = true;
        requestApply(requested, isStartup ? "startup" : "automatic", false);
    }

    function loadState(text: string): void {
        try {
            const data = JSON.parse(text);
            const mode = data.mode === "manual" ? "manual" : "auto";
            const selected = validProfiles.includes(data.selectedProfile) ? data.selectedProfile : "auto";
            profileMode = selected === "auto" ? "auto" : mode;
            selectedProfile = mode === "auto" ? "auto" : selected;
            lastAppliedProfile = validProfiles.includes(data.lastAppliedProfile) && data.lastAppliedProfile !== "auto" ? data.lastAppliedProfile : "";
            lastTopologySignature = String(data.lastTopologySignature ?? "");
        } catch (error) {
            console.warn(lc, `Ignoring invalid monitor profile state: ${error}`);
            profileMode = "auto";
            selectedProfile = "auto";
        }
        stateLoaded = true;
        if (monitorSnapshots.length > 0)
            maybeApplyPolicy("state-loaded");
    }

    function saveState(): void {
        if (!stateLoaded)
            return;
        stateFile.setText(JSON.stringify({
            mode: profileMode,
            selectedProfile,
            lastAppliedProfile,
            lastTopologySignature
        }, null, 2) + "\n");
    }

    function focusedScreen(): ShellScreen {
        const focusedName = Hypr.focusedMonitor?.name ?? "";
        return Screens.screens.find(screen => screen.name === focusedName)
            ?? Screens.screens[0]
            ?? null;
    }

    function toggleOverlay(): void {
        if (overlayLoader.active) {
            if (overlayLoader.item)
                overlayLoader.item.close();
            else
                overlayLoader.activeAsync = false;
            return;
        }

        const screen = focusedScreen();
        if (!screen) {
            showFailure(qsTr("No enabled screen is available for the monitor profile overlay"));
            return;
        }
        targetScreen = screen;
        overlaySnapshots = cloneSnapshots(monitorSnapshots);
        overlayLoader.activeAsync = true;
    }

    function forceCloseOverlay(): void {
        overlayLoader.closing = true;
        overlayLoader.activeAsync = false;
    }

    Component.onCompleted: {
        topologyDebounce.start();
    }

    Timer {
        id: topologyDebounce

        interval: 750
        onTriggered: root.requestTopologyQuery("event")
    }

    Timer {
        id: verificationTimer

        interval: 350
        onTriggered: root.requestTopologyQuery(root.operationStage === "final" ? "final" : "verify")
    }

    Connections {
        function onValuesChanged(): void {
            root.scheduleTopologyProbe();
        }

        target: Hypr.monitors
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            if (["monitoradded", "monitorremoved", "monitoraddedv2", "monitorremovedv2"].includes(event.name))
                root.scheduleTopologyProbe();
        }

        target: Hyprland
    }

    FileView {
        id: stateFile

        path: `${Paths.state}/monitor-profiles.json`
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadState(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn(lc, `Unable to load monitor profile state: ${FileViewError.toString(error)}`);
            root.stateLoaded = true;
            Qt.callLater(() => {
                root.saveState();
                if (root.monitorSnapshots.length > 0)
                    root.maybeApplyPolicy("state-created");
            });
        }
        onSaveFailed: error => console.warn(lc, `Unable to save monitor profile state: ${FileViewError.toString(error)}`)
    }

    Process {
        id: topologyProcess

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleTopologyResult(text)
        }
        stderr: StdioCollector {
            id: topologyStderr

            waitForEnd: true
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                const purpose = root.topologyPurpose;
                root.topologyPurpose = "";
                const detail = topologyStderr.text.trim() || qsTr("hyprctl monitors failed");
                if (purpose === "event")
                    console.warn(lc, detail);
                else
                    root.failApply(detail);
            }
            Qt.callLater(root.runQueuedTopologyQuery);
        }
    }

    Process {
        id: applyProcess

        stdout: StdioCollector {
            id: applyStdout

            waitForEnd: true
        }
        stderr: StdioCollector {
            id: applyStderr

            waitForEnd: true
        }
        onExited: exitCode => root.handleApplyExit(exitCode)
    }

    LazyLoader {
        id: overlayLoader

        property bool closing

        MonitorProfilesWindow {
            controller: root
            loader: overlayLoader
            screen: root.targetScreen
            snapshots: root.overlaySnapshots
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "monitorProfiles"
        description: "Toggle smart monitor profiles"
        onPressed: root.toggleOverlay()
    }

    IpcHandler {
        function toggle(): void {
            root.toggleOverlay();
        }

        function close(): void {
            root.forceCloseOverlay();
        }

        function isOpen(): bool {
            return overlayLoader.active;
        }

        function profile(): string {
            return root.selectedProfile;
        }

        function appliedProfile(): string {
            return root.lastAppliedProfile;
        }

        function topology(): string {
            return JSON.stringify(root.monitorSnapshots);
        }

        function apply(profile: string): string {
            return root.requestApply(profile, "manual", true) ? "started" : "rejected";
        }

        target: "monitorProfiles"
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.monitorprofiles"
        defaultLogLevel: LoggingCategory.Info
    }
}
