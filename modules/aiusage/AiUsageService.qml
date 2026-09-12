pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Scope {
    id: root

    readonly property int refreshInterval: 5 * 60 * 1000
    readonly property int staleAfter: 12 * 60 * 1000
    readonly property int retryGuard: 30 * 1000
    readonly property string codexHelperPath: Paths.toLocalFile(Qt.resolvedUrl("helpers/codex_quota.py"))
    readonly property string antigravityCachePath: `${Quickshell.env("XDG_CACHE_HOME") || `${Paths.home}/.cache`}/caelestia-ai-usage/antigravity.json`
    readonly property var codex: codexState
    readonly property var antigravity: antigravityState
    readonly property double mostRecentUpdatedAt: Math.max(codexState.updatedAt, antigravityState.updatedAt)

    property double now: Date.now()
    property double codexLastAttemptAt
    property bool codexOutputReceived

    function validPercent(value: var): bool {
        return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 100;
    }

    function parseTimestamp(value: var): double {
        if (typeof value !== "string" || !value.length)
            return 0;
        const parsed = Date.parse(value);
        return Number.isFinite(parsed) ? parsed : 0;
    }

    function validateCodexQuotas(value: var): var {
        if (!Array.isArray(value))
            return [];
        const quotas = [];
        for (const raw of value) {
            if (!raw || typeof raw !== "object" || !validPercent(raw.remainingPercent))
                continue;
            quotas.push({
                id: String(raw.id ?? `${raw.limitId ?? "codex"}-${raw.slot ?? quotas.length}`),
                label: String(raw.label ?? "Quota window"),
                remainingPercent: raw.remainingPercent,
                resetAt: typeof raw.resetAt === "number" && Number.isFinite(raw.resetAt) ? raw.resetAt : null,
                windowDurationMins: typeof raw.windowDurationMins === "number" && Number.isFinite(raw.windowDurationMins) ? raw.windowDurationMins : null
            });
        }
        return quotas;
    }

    function validateAntigravityQuotas(value: var): var {
        if (!Array.isArray(value))
            return [];
        const quotas = [];
        for (const raw of value) {
            if (!raw || typeof raw !== "object" || typeof raw.id !== "string" || !validPercent(raw.remainingPercent))
                continue;
            let resetAt = 0;
            if (typeof raw.resetTime === "string") {
                const parsed = Date.parse(raw.resetTime);
                if (Number.isFinite(parsed))
                    resetAt = parsed / 1000;
            }
            if (!resetAt && typeof raw.resetInSeconds === "number" && Number.isFinite(raw.resetInSeconds))
                resetAt = (Date.now() / 1000) + Math.max(0, raw.resetInSeconds);
            quotas.push({
                id: raw.id,
                label: formatAntigravityLabel(raw.id),
                remainingPercent: raw.remainingPercent,
                resetAt: resetAt || null,
                resetInSeconds: typeof raw.resetInSeconds === "number" && Number.isFinite(raw.resetInSeconds) ? Math.max(0, raw.resetInSeconds) : null
            });
        }
        return quotas;
    }

    function formatAntigravityLabel(id: string): string {
        const words = id.replace(/[_-]+/g, " ").trim().split(/\s+/).filter(word => word.length > 0);
        if (!words.length)
            return qsTr("Quota window");
        return words.map(word => {
            const lower = word.toLowerCase();
            if (lower === "gemini")
                return "Gemini";
            if (lower === "3p")
                return "3P";
            if (lower === "weekly")
                return qsTr("weekly");
            return word.charAt(0).toUpperCase() + word.slice(1);
        }).join(" ");
    }

    function updateStaleStates(): void {
        codexState.stale = codexState.updatedAt > 0 && now - codexState.updatedAt > staleAfter;
        antigravityState.stale = antigravityState.updatedAt > 0 && now - antigravityState.updatedAt > staleAfter;
    }

    function refreshIfStale(): void {
        const age = codexState.updatedAt > 0 ? Date.now() - codexState.updatedAt : Number.POSITIVE_INFINITY;
        if (age >= refreshInterval)
            refreshCodex(false);
        antigravityFile.reload();
    }

    function refreshCodex(force: bool): void {
        const current = Date.now();
        if (codexProcess.running || current - codexLastAttemptAt < retryGuard)
            return;
        if (!force && codexState.updatedAt > 0 && current - codexState.updatedAt < refreshInterval)
            return;

        codexLastAttemptAt = current;
        codexOutputReceived = false;
        codexState.loading = true;
        codexState.error = "";
        codexProcess.exec(["python3", codexHelperPath]);
    }

    function acceptCodex(text: string): void {
        codexOutputReceived = true;
        let data;
        try {
            data = JSON.parse(text);
        } catch (error) {
            codexState.loading = false;
            codexState.error = qsTr("Codex returned an invalid quota response");
            updateStaleStates();
            return;
        }

        const quotas = validateCodexQuotas(data.quotas);
        if (data.available === true && quotas.length > 0) {
            codexState.available = true;
            codexState.plan = typeof data.plan === "string" ? data.plan : "";
            codexState.quotas = quotas;
            codexState.updatedAt = parseTimestamp(data.updatedAt) || Date.now();
            codexState.resetCreditsAvailable = typeof data.resetCreditsAvailable === "number" ? Math.max(0, Math.floor(data.resetCreditsAvailable)) : -1;
            codexState.error = "";
        } else {
            codexState.error = typeof data.error === "string" && data.error.length ? data.error : qsTr("Codex quota is unavailable");
        }
        codexState.loading = false;
        updateStaleStates();
    }

    function acceptAntigravity(text: string): void {
        let data;
        try {
            data = JSON.parse(text);
        } catch (error) {
            antigravityState.loading = false;
            antigravityState.error = qsTr("Antigravity quota cache is invalid");
            updateStaleStates();
            return;
        }

        const quotas = validateAntigravityQuotas(data.quotas);
        if (quotas.length > 0) {
            antigravityState.available = true;
            antigravityState.plan = typeof data.planTier === "string" ? data.planTier : "";
            antigravityState.quotas = quotas;
            antigravityState.updatedAt = parseTimestamp(data.updatedAt) || Date.now();
            antigravityState.error = "";
        } else {
            antigravityState.error = qsTr("Waiting for Antigravity quota");
        }
        antigravityState.loading = false;
        updateStaleStates();
    }

    QtObject {
        id: codexState

        property bool available
        property bool loading: true
        property bool stale
        property string plan
        property var quotas: []
        property string error
        property double updatedAt
        property int resetCreditsAvailable: -1
    }

    QtObject {
        id: antigravityState

        property bool available
        property bool loading: true
        property bool stale
        property string plan
        property var quotas: []
        property string error
        property double updatedAt
    }

    Process {
        id: codexProcess

        stdout: StdioCollector {
            onStreamFinished: root.acceptCodex(text)
        }

        onExited: exitCode => {
            Qt.callLater(() => {
                if (root.codexOutputReceived)
                    return;
                codexState.loading = false;
                codexState.error = exitCode === 0 ? qsTr("Codex returned no quota data") : qsTr("Codex quota collector could not start");
                root.updateStaleStates();
            });
        }
    }

    FileView {
        id: antigravityFile

        path: root.antigravityCachePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.acceptAntigravity(text())
        onLoadFailed: error => {
            antigravityState.loading = false;
            if (error === FileViewError.FileNotFound)
                antigravityState.error = qsTr("Waiting for Antigravity quota");
            else
                antigravityState.error = qsTr("Antigravity quota cache is unavailable");
            root.updateStaleStates();
        }
    }

    Timer {
        interval: 1200
        running: true
        onTriggered: root.refreshCodex(true)
    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        onTriggered: root.refreshCodex(false)
    }

    Timer {
        interval: 15 * 1000
        running: true
        repeat: true
        onTriggered: antigravityFile.reload()
    }

    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            root.updateStaleStates();
        }
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.aiusage.service"
    }
}
