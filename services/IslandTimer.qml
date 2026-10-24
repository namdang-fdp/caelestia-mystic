pragma Singleton

import QtQuick
import Quickshell
import "../modules/dashboard/helpers/ActivityLogic.js" as Logic

// Countdown and Pomodoro live activity. Deadlines are wall-clock based, so
// suspend/resume catches up instead of drifting.
Singleton {
    id: root
    readonly property var phaseMinutes: ({ focus: 25, break: 5, longBreak: 15 })
    readonly property bool active: state.deadline > 0 || state.saved > 0
    readonly property bool paused: active && state.deadline === 0
    readonly property bool ticking: active && !paused
    readonly property real remaining: Logic.timerRemaining(ticking, state.deadline, state.saved, now)
    readonly property real duration: state.duration
    readonly property real progress: duration > 0 ? Math.min(1, Math.max(0, 1 - remaining / duration)) : 0
    readonly property string phase: state.phase
    readonly property bool pomodoro: state.pomodoro
    readonly property int completed: state.completed
    readonly property string label: !pomodoro ? qsTr("Timer") : phase === "focus" ? qsTr("Focus") : phase === "longBreak" ? qsTr("Long break") : qsTr("Break")
    readonly property string clock: Logic.clock(remaining / 1000)
    property real now: Date.now()
    signal finished(string phase, bool pomodoro)

    function start(minutes: var): void {
        const n = Logic.durationMinutes(minutes);
        if (!n) return;
        state.pomodoro = false;
        state.phase = "timer";
        begin(n * 60000);
    }
    function startPomodoro(): void {
        state.pomodoro = true;
        state.completed = 0;
        state.phase = "focus";
        begin(phaseMinutes.focus * 60000);
    }
    function begin(ms: real): void {
        now = Date.now();
        state.duration = ms;
        state.saved = 0;
        state.deadline = now + ms;
    }
    function pause(): void {
        if (!ticking) return;
        state.saved = Math.max(1, Logic.remaining(state.deadline, Date.now()));
        state.deadline = 0;
    }
    function resume(): void {
        if (!paused) return;
        now = Date.now();
        state.deadline = now + state.saved;
        state.saved = 0;
    }
    function toggle(): void { if (paused) resume(); else pause(); }
    function addMinutes(minutes: int): void {
        if (!active) return;
        const ms = minutes * 60000;
        state.duration = Math.max(60000, state.duration + ms);
        if (paused) state.saved = Math.max(1000, state.saved + ms);
        else state.deadline = Math.max(Date.now() + 1000, state.deadline + ms);
    }
    function stop(): void {
        state.deadline = 0;
        state.saved = 0;
        state.duration = 0;
        state.pomodoro = false;
        state.phase = "timer";
    }
    function skip(): void { if (active) finish(); }
    function finish(): void {
        const done = state.phase;
        const wasPomodoro = state.pomodoro;
        if (wasPomodoro) {
            if (done === "focus") state.completed++;
            state.phase = Logic.nextPhase(done, state.completed);
            begin(phaseMinutes[state.phase] * 60000);
        } else {
            stop();
        }
        finished(done, wasPomodoro);
        const title = !wasPomodoro ? qsTr("Timer finished") : done === "focus" ? qsTr("Focus session complete") : qsTr("Break is over");
        const body = !wasPomodoro ? qsTr("Your countdown reached zero.") : state.phase === "focus" ? qsTr("Next: focus for %1 min").arg(phaseMinutes.focus) : qsTr("Next: %1 min break").arg(phaseMinutes[state.phase]);
        Quickshell.execDetached(["notify-send", "-a", "Island", "-i", "alarm-symbolic", "-u", "critical", title, body]);
    }

    PersistentProperties {
        id: state
        reloadableId: "islandTimer"
        property real deadline: 0
        property real saved: 0
        property real duration: 0
        property string phase: "timer"
        property bool pomodoro: false
        property int completed: 0
    }
    Timer {
        interval: 250
        repeat: true
        running: root.ticking
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            if (root.remaining <= 0) root.finish();
        }
    }
}
