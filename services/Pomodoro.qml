pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import qs.services

Singleton {
    id: root

    // Configuration constants (defaults: 50 / 10 / 20, 4 focus sessions)
    readonly property int focusDurationMs: 50 * 60 * 1000
    readonly property int shortBreakDurationMs: 10 * 60 * 1000
    readonly property int longBreakDurationMs: 20 * 60 * 1000
    readonly property int longBreakInterval: 4

    // State properties
    property string phase: "focus" // "focus" | "shortBreak" | "longBreak"
    property bool running: false
    property bool paused: false
    property double deadline: 0
    property int remainingMs: focusDurationMs
    property int completedFocusSessions: 0
    property double now: Date.now()

    // Internal flags & storage
    property bool storageReady: false
    property bool completing: false

    readonly property string cacheDir: `${Paths.home}/.cache/caelestia-pomodoro`
    readonly property string statePath: `${cacheDir}/state.json`

    // Derived helpers
    readonly property bool hasActiveSession: running || paused
    readonly property int totalDurationMs: durationFor(phase)

    readonly property real progress: {
        const total = totalDurationMs;
        if (total <= 0)
            return 0;
        const elapsed = total - remainingMs;
        return Math.max(0, Math.min(1, elapsed / total));
    }

    readonly property int cycleCompleted: {
        if (phase === "longBreak")
            return longBreakInterval;
        return completedFocusSessions % longBreakInterval;
    }

    readonly property string currentPhaseLabel: phaseLabel(phase)
    readonly property string formattedTime: formatTime(remainingMs)

    signal sessionCompleted(string phase)

    function durationFor(p: string): int {
        switch (p) {
        case "shortBreak":
            return shortBreakDurationMs;
        case "longBreak":
            return longBreakDurationMs;
        case "focus":
        default:
            return focusDurationMs;
        }
    }

    function phaseLabel(p: string): string {
        switch (p) {
        case "shortBreak":
            return qsTr("Short Break");
        case "longBreak":
            return qsTr("Long Break");
        case "focus":
        default:
            return qsTr("Focus");
        }
    }

    function formatTime(ms: double): string {
        if (!Number.isFinite(ms) || ms <= 0)
            return "00:00";
        const totalSecs = Math.ceil(ms / 1000);
        const mins = Math.floor(totalSecs / 60);
        const secs = totalSecs % 60;
        return `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
    }

    function resetToDefaults(): void {
        phase = "focus";
        running = false;
        paused = false;
        deadline = 0;
        remainingMs = focusDurationMs;
        completedFocusSessions = 0;
        now = Date.now();
        storageReady = true;
        saveState();
    }

    function start(): void {
        if (running)
            return;
        const epoch = Date.now();
        if (remainingMs <= 0 || remainingMs > durationFor(phase))
            remainingMs = durationFor(phase);
        deadline = epoch + remainingMs;
        running = true;
        paused = false;
        now = epoch;
        saveState();
    }

    function pause(): void {
        if (!running || paused)
            return;
        const epoch = Date.now();
        remainingMs = Math.max(0, Math.round(deadline - epoch));
        deadline = 0;
        running = false;
        paused = true;
        now = epoch;
        saveState();
    }

    function resume(): void {
        if (running || !paused)
            return;
        const epoch = Date.now();
        if (remainingMs <= 0)
            remainingMs = durationFor(phase);
        deadline = epoch + remainingMs;
        running = true;
        paused = false;
        now = epoch;
        saveState();
    }

    function reset(): void {
        running = false;
        paused = false;
        deadline = 0;
        remainingMs = durationFor(phase);
        now = Date.now();
        saveState();
    }

    function skip(): void {
        running = false;
        paused = false;
        deadline = 0;

        if (phase === "focus") {
            phase = "shortBreak";
        } else if (phase === "longBreak") {
            completedFocusSessions = 0;
            phase = "focus";
        } else {
            phase = "focus";
        }

        remainingMs = durationFor(phase);
        now = Date.now();
        saveState();
    }

    function updateRemaining(): void {
        const epoch = Date.now();
        now = epoch;
        if (running && deadline > 0) {
            const rem = Math.max(0, Math.round(deadline - epoch));
            remainingMs = rem;
            if (rem <= 0)
                handlePhaseCompletion();
        }
    }

    function handlePhaseCompletion(): void {
        if (completing)
            return;
        completing = true;
        try {
            running = false;
            paused = false;
            deadline = 0;

            const finishedPhase = phase;
            let nextPhase = "focus";
            let notifSummary = "";
            let notifBody = "";

            if (finishedPhase === "focus") {
                completedFocusSessions++;
                if (completedFocusSessions % longBreakInterval === 0) {
                    nextPhase = "longBreak";
                    notifSummary = qsTr("Focus complete");
                    notifBody = qsTr("Time for a long break.");
                } else {
                    nextPhase = "shortBreak";
                    notifSummary = qsTr("Focus complete");
                    notifBody = qsTr("Time for a short break.");
                }
            } else {
                if (finishedPhase === "longBreak")
                    completedFocusSessions = 0;
                nextPhase = "focus";
                notifSummary = qsTr("Break complete");
                notifBody = qsTr("Ready to focus?");
            }

            phase = nextPhase;
            remainingMs = durationFor(nextPhase);

            sendNotification(notifSummary, notifBody);
            saveState();
            sessionCompleted(finishedPhase);
        } finally {
            completing = false;
        }
    }

    function sendNotification(summary: string, body: string): void {
        notifProcess.exec(["notify-send", summary, body, "-a", "Pomodoro", "-i", "timer", "-u", "normal"]);
    }

    function saveState(): void {
        if (!storageReady)
            return;
        const payload = {
            phase: phase,
            running: running,
            paused: paused,
            deadline: running && deadline > 0 ? deadline : null,
            remainingMs: running ? null : remainingMs,
            completedFocusSessions: completedFocusSessions
        };
        stateFile.setText(JSON.stringify(payload, null, 2));
    }

    function restoreState(content: string): void {
        storageReady = true;
        if (!content || !content.trim()) {
            resetToDefaults();
            return;
        }

        let data;
        try {
            data = JSON.parse(content);
        } catch (e) {
            console.warn(lc, "Malformed pomodoro state JSON, restoring default state: " + e);
            resetToDefaults();
            return;
        }

        if (!data || typeof data !== "object") {
            resetToDefaults();
            return;
        }

        const validPhases = ["focus", "shortBreak", "longBreak"];
        const restoredPhase = validPhases.includes(data.phase) ? data.phase : "focus";
        const restoredCompleted = (typeof data.completedFocusSessions === "number" && data.completedFocusSessions >= 0)
            ? Math.floor(data.completedFocusSessions) : 0;

        phase = restoredPhase;
        completedFocusSessions = restoredCompleted;

        const epoch = Date.now();

        if (data.running && typeof data.deadline === "number" && data.deadline > 0) {
            if (epoch >= data.deadline) {
                // Deadline expired while Quickshell was closed/suspended:
                // Complete safely without stalling at 00:00
                running = true;
                deadline = data.deadline;
                handlePhaseCompletion();
                return;
            } else {
                deadline = data.deadline;
                remainingMs = Math.max(0, Math.round(deadline - epoch));
                running = true;
                paused = false;
            }
        } else if (data.paused || (data.running === false && typeof data.remainingMs === "number" && data.remainingMs > 0 && data.remainingMs < durationFor(restoredPhase))) {
            running = false;
            paused = true;
            deadline = 0;
            remainingMs = Math.min(durationFor(restoredPhase), Math.max(0, Math.round(data.remainingMs)));
        } else {
            running = false;
            paused = false;
            deadline = 0;
            remainingMs = durationFor(restoredPhase);
        }

        now = epoch;
    }

    Timer {
        id: ticker

        interval: 200
        running: root.running
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateRemaining()
    }

    Process {
        id: dirCreator

        onExited: exitCode => {
            if (exitCode === 0) {
                stateFile.path = root.statePath;
            } else {
                console.warn(lc, `Failed to create pomodoro cache dir (${exitCode})`);
                root.storageReady = true;
            }
        }
    }

    FileView {
        id: stateFile

        atomicWrites: true
        printErrors: false

        onLoaded: root.restoreState(text())
        onLoadFailed: error => {
            root.storageReady = true;
            if (error !== FileViewError.FileNotFound)
                console.warn(lc, `Failed to load pomodoro state: ${FileViewError.toString(error)}`);
            root.resetToDefaults();
        }
        onSaveFailed: error => console.warn(lc, `Failed to save pomodoro state: ${FileViewError.toString(error)}`)
    }

    Process {
        id: notifProcess
    }

    IpcHandler {
        target: "pomodoro"

        function status(): string {
            return JSON.stringify({
                phase: root.phase,
                phaseLabel: root.currentPhaseLabel,
                running: root.running,
                paused: root.paused,
                deadline: root.deadline,
                remainingMs: root.remainingMs,
                formattedTime: root.formattedTime,
                progress: root.progress,
                completedFocusSessions: root.completedFocusSessions,
                cycleCompleted: root.cycleCompleted,
                longBreakInterval: root.longBreakInterval
            });
        }

        function start(): void {
            root.start();
        }

        function pause(): void {
            root.pause();
        }

        function resume(): void {
            root.resume();
        }

        function reset(): void {
            root.reset();
        }

        function skip(): void {
            root.skip();
        }

        function togglePopout(): void {
            const comp = ShellState.componentsForActive();
            if (!comp)
                return;
            const panels = comp.panels;
            const bar = comp.bar;
            if (!panels)
                return;
            const popouts = panels.popouts;
            if (popouts.hasCurrent && popouts.currentName === "pomodoro") {
                popouts.hasCurrent = false;
            } else {
                popouts.currentName = "pomodoro";
                if (bar)
                    popouts.currentCenter = bar.height * 0.78;
                popouts.hasCurrent = true;
            }
        }
    }

    Component.onCompleted: {
        dirCreator.exec(["mkdir", "-p", cacheDir]);
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.pomodoro"
        defaultLogLevel: LoggingCategory.Info
    }
}
