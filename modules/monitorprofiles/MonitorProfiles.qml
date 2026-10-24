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

    // Connectors are detected from the live topology: the internal panel is the first
    // eDP/LVDS/DSI output, the external one prefers the last applied external display
    // (matched by description) and otherwise falls back to the first other output.
    readonly property string laptopConnector: laptopNameIn(monitorSnapshots) || storedLaptopConnector
    readonly property string externalConnector: externalNameIn(monitorSnapshots) || storedExternalConnector
    property string storedLaptopConnector
    property string storedExternalConnector
    property string preferredExternalDescription
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

    property double verifyDeadline
    property string operationSignature
    property bool operationLidClosed
    property bool discardApplyExit

    // Clamshell: in auto mode a closed lid with an external display means external-only.
    property string lidStatePath
    property bool lidRawClosed
    property bool lidClosed
    readonly property bool externalPresent: externalNameIn(monitorSnapshots) !== ""

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
        return !!name && monitorNamed(name, snapshots) !== null;
    }

    function isInternalName(name: string): bool {
        return /^(eDP|LVDS|DSI)-/.test(String(name));
    }

    function laptopNameIn(snapshots = monitorSnapshots): string {
        return snapshots.find(snapshot => isInternalName(snapshot.name))?.name ?? "";
    }

    function externalNameIn(snapshots = monitorSnapshots): string {
        const externals = snapshots.filter(snapshot => !isInternalName(snapshot.name));
        if (preferredExternalDescription) {
            const preferred = externals.find(snapshot => snapshot.description === preferredExternalDescription);
            if (preferred)
                return preferred.name;
        }
        return externals[0]?.name ?? "";
    }

    function otherNames(keep: string, snapshots = monitorSnapshots): var {
        return snapshots.filter(snapshot => snapshot.name !== keep).map(snapshot => snapshot.name);
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

    function bestPreferredMode(monitor: var): var {
        const size = preferredSize(monitor);
        const candidates = (monitor.availableModes ?? []).map(mode => {
            const match = String(mode).match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
            if (!match)
                return null;
            return {
                width: Number(match[1]),
                height: Number(match[2]),
                refreshRate: Number(match[3])
            };
        }).filter(mode => mode && mode.width === size.width && mode.height === size.height);
        const best = candidates.reduce((current, mode) => !current || mode.refreshRate > current.refreshRate ? mode : current, null);

        if (!best)
            return {
                width: size.width,
                height: size.height,
                refreshRate: Number(monitor.refreshRate) || 0,
                mode: "preferred"
            };

        return {
            width: best.width,
            height: best.height,
            refreshRate: best.refreshRate,
            mode: `${best.width}x${best.height}@${best.refreshRate}`
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

    function resolveAuto(snapshots = monitorSnapshots, closed = lidClosed): string {
        const laptopName = laptopNameIn(snapshots);
        const externalName = externalNameIn(snapshots);
        if (externalName && laptopName)
            return closed ? "external-only" : "home-dual";
        if (laptopName)
            return "laptop-only";
        return "";
    }

    function makePlan(profile: string, snapshots = monitorSnapshots): var {
        const resolved = profile === "auto" ? resolveAuto(snapshots) : profile;
        const laptopName = laptopNameIn(snapshots);
        const externalName = externalNameIn(snapshots);
        const laptop = monitorNamed(laptopName, snapshots);
        const external = monitorNamed(externalName, snapshots);
        const laptopLabel = laptopName || storedLaptopConnector || qsTr("the laptop display");
        const externalLabel = externalName || storedExternalConnector || qsTr("an external display");

        if (!resolved)
            return {
                error: qsTr("No supported laptop topology is currently available")
            };

        if (resolved === "home-dual") {
            if (!laptop || !external)
                return {
                    error: qsTr("Home Dual requires both %1 and %2").arg(externalLabel).arg(laptopLabel)
                };

            const externalMode = bestPreferredMode(external);
            const laptopMode = bestPreferredMode(laptop);
            const externalScale = validScale(external.scale);
            return {
                profile: resolved,
                enabled: [{
                        name: externalName,
                        width: externalMode.width,
                        height: externalMode.height,
                        refreshRate: externalMode.refreshRate,
                        mode: externalMode.mode,
                        x: 0,
                        y: 0,
                        scale: externalScale
                    }, {
                        name: laptopName,
                        width: laptopMode.width,
                        height: laptopMode.height,
                        refreshRate: laptopMode.refreshRate,
                        mode: laptopMode.mode,
                        x: Math.round(externalMode.width / externalScale),
                        y: 0,
                        scale: validScale(laptop.scale)
                    }],
                disabled: [],
                isolate: "",
                safetyTarget: "",
                laptopName,
                externalName,
                externalDescription: external.description,
                title: qsTr("Home Dual applied"),
                message: qsTr("External left · Laptop right")
            };
        }

        if (resolved === "laptop-only") {
            if (!laptop)
                return {
                    error: qsTr("Laptop Only requires %1").arg(laptopLabel)
                };
            const laptopMode = bestPreferredMode(laptop);
            return {
                profile: resolved,
                enabled: [{
                        name: laptopName,
                        width: laptopMode.width,
                        height: laptopMode.height,
                        refreshRate: laptopMode.refreshRate,
                        mode: laptopMode.mode,
                        x: 0,
                        y: 0,
                        scale: validScale(laptop.scale)
                    }],
                disabled: otherNames(laptopName, snapshots),
                isolate: laptopName,
                safetyTarget: laptopName,
                laptopName,
                externalName: "",
                externalDescription: "",
                title: qsTr("Laptop Mode applied"),
                message: qsTr("%1 restored to 0x0").arg(laptopName)
            };
        }

        if (resolved === "external-only") {
            if (!external)
                return {
                    error: qsTr("External Only requires %1").arg(externalLabel)
                };
            const externalMode = bestPreferredMode(external);
            return {
                profile: resolved,
                enabled: [{
                        name: externalName,
                        width: externalMode.width,
                        height: externalMode.height,
                        refreshRate: externalMode.refreshRate,
                        mode: externalMode.mode,
                        x: 0,
                        y: 0,
                        scale: validScale(external.scale)
                    }],
                disabled: otherNames(externalName, snapshots),
                isolate: externalName,
                safetyTarget: externalName,
                laptopName,
                externalName,
                externalDescription: external.description,
                title: qsTr("External Mode applied"),
                message: qsTr("%1 active at 0x0").arg(externalName)
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
            if (desired.refreshRate > 0 && Math.abs(current.refreshRate - desired.refreshRate) > 0.1)
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
            `mode = ${luaQuote(monitor.mode ?? "preferred")},`,
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

    function isOperationPurpose(purpose: string): bool {
        return ["preflight", "verify", "final"].includes(purpose);
    }

    function handleTopologyResult(text: string): void {
        const purpose = topologyPurpose;
        topologyPurpose = "";
        // An empty purpose means the result was already handled or abandoned.
        if (!purpose) {
            Qt.callLater(runQueuedTopologyQuery);
            return;
        }
        let data;
        try {
            data = JSON.parse(text);
            if (!Array.isArray(data))
                throw new Error("Hyprland returned a non-array monitor response");
        } catch (error) {
            if (isOperationPurpose(purpose))
                failApply(qsTr("Unable to read connected monitors: %1").arg(error));
            else
                console.warn(lc, `Unable to parse monitor topology: ${error}`);
            Qt.callLater(runQueuedTopologyQuery);
            return;
        }

        updateTopology(data);
        if (overlayLoader.active && !overlayLoader.closing)
            overlaySnapshots = cloneSnapshots(monitorSnapshots);

        if (purpose === "preflight")
            beginApplyAfterPreflight();
        else if (purpose === "verify")
            verifyConfiguredMonitors();
        else if (purpose === "final")
            finishApplyAfterVerification();
        else if (purpose !== "overlay")
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
        applyTimeout.restart();
        if (!applyProcess.running)
            discardApplyExit = false;
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

        if (operationRequestedProfile === "auto")
            syncLidState();
        const plan = makePlan(operationRequestedProfile);
        if (plan.error) {
            failApply(plan.error);
            return;
        }

        operationLidClosed = lidClosed;
        if (profileMatches(plan)) {
            // Already in the requested layout: never re-apply (avoids a modeset
            // flicker on every shell restart) and only confirm manual requests.
            operationPlan = plan;
            completeApply(operationSource === "manual");
            return;
        }

        operationPlan = plan;
        operationGeneration = topologyGeneration;
        operationSignature = topologySignature;
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
            verifyDeadline = Date.now() + verifyWindow;
            verificationTimer.restart();
        } else if (operationStage === "disable") {
            operationStage = "final";
            verifyDeadline = Date.now() + verifyWindow;
            verificationTimer.restart();
        }
    }

    // HDMI links can take a second or more to come up, so keep re-querying until the
    // deadline instead of judging the layout from a single early snapshot.
    function retryVerification(): bool {
        if (Date.now() >= verifyDeadline)
            return false;
        verificationTimer.restart();
        return true;
    }

    function verifyConfiguredMonitors(): void {
        if (!applying || operationStage !== "verify")
            return;
        if (topologySignature !== operationSignature) {
            if (!retryVerification())
                failApply(qsTr("Monitor topology changed while applying the profile"));
            return;
        }

        for (const desired of operationPlan.enabled) {
            const current = monitorNamed(desired.name);
            if (!current || !current.enabled) {
                if (!retryVerification())
                    failApply(qsTr("%1 did not become active; the existing display was left enabled").arg(desired.name));
                return;
            }
        }

        // Re-derive what to disable from the live topology so a single-display
        // profile always turns off every other output.
        if (operationPlan.isolate)
            operationPlan = Object.assign({}, operationPlan, {
                disabled: otherNames(operationPlan.isolate)
            });

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
        if (topologySignature !== operationSignature) {
            if (!retryVerification())
                failApply(qsTr("Monitor topology changed before the profile finished"));
            return;
        }
        if (!profileMatches(operationPlan)) {
            if (!retryVerification())
                failApply(qsTr("Hyprland did not reach the requested monitor layout"));
            return;
        }
        completeApply(true);
    }

    function policyKey(closed = lidClosed): string {
        const lid = profileMode === "auto" ? (closed ? ":lid-closed" : ":lid-open") : "";
        return `${profileMode}:${selectedProfile}:${topologySignature}${lid}`;
    }

    function stopOperationTimers(): void {
        applyTimeout.stop();
        verificationTimer.stop();
    }

    function abortHungApply(): void {
        if (!applying)
            return;
        if (applyProcess.running) {
            discardApplyExit = true;
            applyProcess.running = false;
        }
        if (topologyProcess.running && isOperationPurpose(topologyPurpose)) {
            topologyPurpose = "";
            topologyProcess.running = false;
        }
        failApply(qsTr("Timed out waiting for Hyprland to apply the monitor profile"));
    }

    function completeApply(showToast: bool): void {
        const plan = operationPlan;
        const requested = operationRequestedProfile;
        const changesSelection = operationChangesSelection;

        applying = false;
        operationStage = "";
        operationPlan = null;
        stopOperationTimers();

        if (changesSelection) {
            selectedProfile = requested;
            profileMode = requested === "auto" ? "auto" : "manual";
        }
        rememberConnectors(plan);
        lastAppliedProfile = plan.profile;
        lastTopologySignature = topologySignature;
        lastPolicyKey = policyKey(operationLidClosed);
        saveState();

        if (showToast)
            showSuccess(plan.title, plan.message);

        // The lid may have moved while this profile was being applied.
        if (lastPolicyKey !== policyKey())
            Qt.callLater(() => root.requestTopologyQuery("lid"));
    }

    function rememberConnectors(plan: var): void {
        if (plan.laptopName)
            storedLaptopConnector = plan.laptopName;
        if (plan.externalName) {
            storedExternalConnector = plan.externalName;
            if (plan.externalDescription)
                preferredExternalDescription = plan.externalDescription;
        }
    }

    function failApply(message: string): void {
        if (!applying)
            return;
        stopOperationTimers();
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

        if (profileMode === "auto")
            syncLidState();

        const isStartup = !startupHandled;
        let requested = profileMode === "auto" ? "auto" : selectedProfile;
        let plan = makePlan(requested);

        if (plan.error && profileMode === "manual" && laptopNameIn() && !externalNameIn()) {
            requested = "laptop-only";
            plan = makePlan(requested);
        }
        if (plan.error) {
            if (isStartup)
                startupHandled = true;
            console.info(lc, `Monitor policy is waiting for a compatible topology: ${plan.error}`);
            return;
        }

        const key = policyKey();
        if (profileMatches(plan)) {
            // Nothing to do. On startup this is the common case after a shell
            // restart, so stay silent and do not touch the monitors.
            startupHandled = true;
            if (key === lastPolicyKey)
                return;
            const profileChanged = lastAppliedProfile !== plan.profile;
            const changed = profileChanged || lastTopologySignature !== topologySignature;
            lastPolicyKey = key;
            lastAppliedProfile = plan.profile;
            lastTopologySignature = topologySignature;
            rememberConnectors(plan);
            if (changed)
                saveState();
            if (profileChanged && !isStartup)
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
            storedLaptopConnector = String(data.laptopConnector ?? "");
            storedExternalConnector = String(data.externalConnector ?? "");
            preferredExternalDescription = String(data.externalDescription ?? "");
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
            lastTopologySignature,
            laptopConnector: storedLaptopConnector,
            externalConnector: storedExternalConnector,
            externalDescription: preferredExternalDescription
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
        // Show the cached snapshot immediately, then refresh it from Hyprland.
        requestTopologyQuery("overlay");
    }

    function handleLidText(text: string): void {
        lidRawClosed = /closed/i.test(text);
    }

    // Reads the lid synchronously (blockLoading) so topology-driven policy decisions
    // never act on a stale lid state.
    function syncLidState(): bool {
        if (!lidStatePath || !externalPresent)
            return false;
        lidFile.reload();
        handleLidText(lidFile.text());
        lidDebounce.stop();
        const changed = lidClosed !== lidRawClosed;
        lidClosed = lidRawClosed;
        return changed;
    }

    function commitLidState(): void {
        if (lidClosed === lidRawClosed)
            return;
        lidClosed = lidRawClosed;
        console.info(lc, `Laptop lid ${lidClosed ? "closed" : "opened"}`);
        if (profileMode === "auto" && externalPresent)
            requestTopologyQuery("lid");
    }

    onLidRawClosedChanged: {
        if (lidRawClosed !== lidClosed)
            lidDebounce.restart();
        else
            lidDebounce.stop();
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

    readonly property int verifyWindow: 3000

    Timer {
        id: verificationTimer

        interval: 350
        onTriggered: {
            if (root.operationStage === "verify" || root.operationStage === "final")
                root.requestTopologyQuery(root.operationStage);
        }
    }

    // A hung hyprctl must never leave `applying` stuck and block future applies.
    Timer {
        id: applyTimeout

        interval: 8000
        onTriggered: root.abortHungApply()
    }

    Timer {
        id: lidDebounce

        interval: 1000
        onTriggered: root.commitLidState()
    }

    // Light lid poll, only while it can matter (auto mode with an external display).
    Timer {
        interval: 2000
        repeat: true
        running: root.lidStatePath !== "" && root.profileMode === "auto" && root.externalPresent
        onTriggered: lidFile.reload()
    }

    FileView {
        id: lidFile

        path: root.lidStatePath
        blockLoading: true
        printErrors: false
        onLoaded: root.handleLidText(text())
    }

    Process {
        id: lidProbe

        running: true
        command: ["sh", "-c", "for f in /proc/acpi/button/lid/*/state; do [ -r \"$f\" ] && { echo \"$f\"; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim().split("\n")[0] ?? "";
                if (!path)
                    return;
                root.lidStatePath = path;
                if (root.syncLidState() && root.profileMode === "auto")
                    root.requestTopologyQuery("lid");
            }
        }
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
            if (exitCode !== 0 && root.topologyPurpose) {
                const purpose = root.topologyPurpose;
                root.topologyPurpose = "";
                const detail = topologyStderr.text.trim() || qsTr("hyprctl monitors failed");
                if (root.isOperationPurpose(purpose))
                    root.failApply(detail);
                else
                    console.warn(lc, detail);
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
        onExited: exitCode => {
            if (root.discardApplyExit) {
                root.discardApplyExit = false;
                return;
            }
            root.handleApplyExit(exitCode);
        }
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

        function lid(): string {
            return JSON.stringify({
                path: root.lidStatePath,
                closed: root.lidClosed,
                raw: root.lidRawClosed,
                laptop: root.laptopConnector,
                external: root.externalConnector
            });
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
