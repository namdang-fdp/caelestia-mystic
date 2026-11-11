pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import "../modules/dashboard/helpers/AgentLogic.js" as Logic

// Live state of Claude Code and Codex sessions (written by agent_hook.py)
// plus token statistics read from their local logs.
Singleton {
    id: root

    readonly property string directory: `${Paths.state}/agents`
    readonly property string hook: Quickshell.shellPath("modules/dashboard/helpers/agent_hook.py")
    readonly property string sessionsHelper: Quickshell.shellPath("modules/dashboard/helpers/agent_sessions.py")
    readonly property string setupHelper: Quickshell.shellPath("modules/dashboard/helpers/agent_setup.py")
    readonly property string statsHelper: Quickshell.shellPath("modules/dashboard/helpers/agent_stats.py")

    property var sessions: []
    property double now: Date.now()
    property var stats: ({ providers: {} })
    // Pages that show statistics ask for them while visible.
    property int viewers

    readonly property var live: Logic.live(sessions, now)
    readonly property string foreground: IslandTools.agentNotch ? Logic.foreground(sessions, now) : ""
    readonly property var primary: Logic.primary(sessions, now)
    readonly property int busy: Logic.busyCount(sessions, now)
    readonly property bool hasSessions: live.length > 0
    readonly property bool hasStats: !!(stats.providers?.claude?.available || stats.providers?.codex?.available)

    // Fired when a session starts waiting for approval or finishes its work.
    signal waiting(var session)
    signal finished(var session)

    // Claude Code hooks are switched on automatically, once per start, if missing.
    property bool autoTried
    function setup(action: string): void {
        if (setupProcess.running) return;
        setupProcess.command = ["python3", "-I", setupHelper, action, "claude"];
        setupProcess.running = true;
    }

    property var lastStates: ({})
    property bool primed

    function provider(key: string): var { return stats.providers?.[key] ?? null; }
    function refreshStats(): void { if (!statsProcess.running) statsProcess.running = true; }
    function accept(text: string): void {
        const next = [];
        for (const line of text.split("\n")) {
            if (!line.trim()) continue;
            try { next.push(JSON.parse(line)); } catch (_) {}
        }
        const stamp = Date.now();
        const result = Logic.diff(primed ? lastStates : null, next, stamp);
        // The first read after startup only learns the current states.
        if (primed) {
            for (const e of result.events) {
                if (e.type === "waiting") waiting(e.session);
                else finished(e.session);
            }
        }
        primed = true;
        lastStates = result.states;
        now = stamp;
        // Skip the model rebuild when nothing relevant changed.
        if (JSON.stringify(next) !== JSON.stringify(sessions)) sessions = next;
    }

    Process {
        id: readProcess
        command: ["python3", "-I", root.sessionsHelper]
        stdout: StdioCollector { onStreamFinished: root.accept(text) }
    }
    Process {
        id: statsProcess
        command: ["python3", "-I", root.statsHelper]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.stats = JSON.parse(text); } catch (_) {}
            }
        }
    }
    Process {
        id: setupProcess
        running: true
        command: ["python3", "-I", root.setupHelper, "status", "claude"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (!r.installed && !r.error && r.available && !root.autoTried) {
                        root.autoTried = true;
                        root.setup("install");
                    }
                } catch (_) {}
            }
        }
    }
    // Quick while an agent is active, relaxed otherwise; also keeps "now" fresh for expiry.
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.hasSessions ? 1000 : 3000
        onTriggered: if (!readProcess.running) readProcess.running = true
    }
    Timer {
        running: root.viewers > 0
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: root.refreshStats()
    }
    // A single cheap read at startup so the Home card can show data.
    Timer { running: true; interval: 4000; onTriggered: root.refreshStats() }
}
