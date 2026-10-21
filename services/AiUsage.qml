pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services

// Claude and Codex plan usage, collected by the helpers in modules/dock/helpers
Singleton {
    id: root

    readonly property Provider claude: Provider {
        key: "claude"
        name: "Claude"
        icon: "claude-desktop"
        script: "claude_usage.py"
        enabled: DockConfig.showClaudeUsage
    }
    readonly property Provider codex: Provider {
        key: "codex"
        name: "Codex"
        icon: "chatgpt"
        script: "codex_usage.py"
        enabled: DockConfig.showCodexUsage
    }

    readonly property list<Provider> providers: [claude, codex].filter(p => p.enabled)
    readonly property bool active: DockConfig.enabled && providers.length > 0

    // Ticks so relative reset times stay current
    property double now: Date.now()

    function provider(key: string): Provider {
        return key === "claude" ? claude : key === "codex" ? codex : null;
    }

    function refresh(force: bool): void {
        for (const p of providers)
            p.refresh(force);
    }

    function severity(percent: real): int {
        return percent >= 90 ? 2 : percent >= 70 ? 1 : 0;
    }

    function severityColour(percent: real): color {
        const level = severity(percent);
        return level === 2 ? "#ff453a" : level === 1 ? "#ff9f0a" : Colours.palette.m3onSurface;
    }

    function resetText(resetsAt: real): string {
        if (!resetsAt)
            return "";
        const ms = resetsAt * 1000 - now;
        if (ms <= 60000)
            return qsTr("Resets now");
        const mins = Math.round(ms / 60000);
        if (mins < 60)
            return qsTr("Resets in %1m").arg(mins);
        if (mins < 24 * 60)
            return qsTr("Resets in %1h %2m").arg(Math.floor(mins / 60)).arg(mins % 60);
        return qsTr("Resets %1").arg(Qt.formatDateTime(new Date(resetsAt * 1000), "ddd HH:mm"));
    }

    function updatedText(updatedAt: real): string {
        if (!updatedAt)
            return qsTr("Not updated yet");
        const mins = Math.floor((now - updatedAt) / 60000);
        if (mins < 1)
            return qsTr("Updated just now");
        if (mins < 60)
            return qsTr("Updated %1 min ago").arg(mins);
        return qsTr("Updated %1h ago").arg(Math.floor(mins / 60));
    }

    Timer {
        running: root.active
        repeat: true
        triggeredOnStart: true
        interval: Math.max(1, DockConfig.usageInterval) * 60000
        onTriggered: root.refresh(false)
    }

    Timer {
        running: root.active
        repeat: true
        interval: 30000
        onTriggered: root.now = Date.now()
    }

    component Provider: QtObject {
        id: provider

        required property string key
        required property string name
        required property string icon
        required property string script
        property bool enabled

        property bool loading
        property bool available
        property string plan
        property string error
        property var limits: []
        property double updatedAt
        property double lastAttemptAt
        property bool hasBaseline
        property var warned: ({})

        readonly property var session: limits.find(l => l.id === "session") ?? null
        readonly property var weekly: limits.find(l => l.id === "weekly") ?? null
        readonly property real peak: Math.max(session?.usedPercent ?? 0, weekly?.usedPercent ?? 0)
        readonly property bool stale: updatedAt > 0 && root.now - updatedAt > Math.max(1, DockConfig.usageInterval) * 120000

        readonly property Process process: Process {
            command: ["python3", "-I", `${Quickshell.shellDir}/modules/dock/helpers/${provider.script}`]
            stdout: StdioCollector {
                onStreamFinished: provider.accept(text)
            }
            onExited: provider.loading = false
        }

        function refresh(force: bool): void {
            const t = Date.now();
            // Guard against hammering the endpoints when the popup is reopened quickly
            if (process.running || (!force && t - lastAttemptAt < 30000) || (force && t - lastAttemptAt < 5000))
                return;
            lastAttemptAt = t;
            loading = true;
            process.running = true;
        }

        function accept(text: string): void {
            let data;
            try {
                data = JSON.parse(text);
            } catch (e) {
                error = qsTr("%1 returned an invalid response").arg(name);
                return;
            }

            if (!data.available) {
                error = data.error || qsTr("%1 usage is unavailable").arg(name);
                available = limits.length > 0;
                return;
            }

            available = true;
            error = "";
            plan = data.plan ?? "";
            limits = data.limits ?? [];
            updatedAt = Date.now();
            root.now = updatedAt;
            checkWarnings();
        }

        function checkWarnings(): void {
            const next = Object.assign({}, warned);
            for (const limit of [session, weekly]) {
                if (!limit)
                    continue;
                const threshold = limit.usedPercent >= 95 ? 95 : limit.usedPercent >= 80 ? 80 : 0;
                if (!threshold)
                    continue;
                // One warning per threshold per limit window
                const id = `${limit.id}:${Math.round(limit.resetsAt ?? 0)}:${threshold}`;
                if (next[id])
                    continue;
                next[id] = true;
                if (hasBaseline && DockConfig.usageWarnings)
                    Toaster.toast(qsTr("%1 %2 usage at %3%").arg(name).arg(limit.label.toLowerCase()).arg(Math.round(limit.usedPercent)), root.resetText(limit.resetsAt), "data_usage", threshold >= 95 ? Toast.Error : Toast.Warning);
            }
            warned = next;
            hasBaseline = true;
        }
    }
}
