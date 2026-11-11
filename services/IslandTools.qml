pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import "../modules/dashboard/helpers/ToolsLogic.js" as Logic
import "../modules/dashboard/helpers/MusicLogic.js" as Music

// State behind the Tools page: quick notes, todos, world clocks, eye breaks,
// timed keep-awake and presentation mode.
Singleton {
    id: root

    property bool loaded
    // Which Tools tab is showing; shortcuts can open a specific one.
    property string tab: "notes"
    signal focusNotes
    function openTab(name: string): void { tab = name; if (name === "notes") focusNotes(); }
    readonly property string notes: adapter.notes
    readonly property var todos: Logic.list(adapter.todos)
    readonly property var clocksConfig: Logic.list(adapter.clocks).filter(c => c && c.name && Logic.validZone(c.tz))
    readonly property bool eyeBreakEnabled: adapter.eyeBreak
    readonly property int eyeInterval: adapter.eyeInterval
    readonly property var musicExtras: Music.extras(adapter.musicExtras)
    function toggleMusicExtra(id: string): void { if (loaded) adapter.musicExtras = Music.toggleExtra(adapter.musicExtras, id); }
    readonly property string petName: adapter.petName || "Mochi"
    readonly property int petKind: adapter.petKind
    readonly property bool agentNotch: adapter.agentNotch
    function setPetName(name: string): void { if (loaded) adapter.petName = name.trim().slice(0, 16); }
    function setPetKind(kind: int): void { if (loaded) adapter.petKind = Math.max(0, Math.min(3, kind)); }
    function setAgentNotch(on: bool): void { if (loaded) adapter.agentNotch = on; }
    readonly property bool glass: adapter.glass
    function setGlass(on: bool): void { if (loaded) adapter.glass = on; }
    readonly property int openTodos: Logic.openCount(adapter.todos)

    function setNotes(text: string): void { if (loaded && text !== adapter.notes) adapter.notes = text.slice(0, 4000); }
    function addTodo(text: string): void { if (loaded) adapter.todos = Logic.addTodo(adapter.todos, text, Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36)); }
    function toggleTodo(id: string): void { if (loaded) adapter.todos = Logic.toggleTodo(adapter.todos, id); }
    function removeTodo(id: string): void { if (loaded) adapter.todos = Logic.removeTodo(adapter.todos, id); }
    function clearDone(): void { if (loaded) adapter.todos = Logic.clearDone(adapter.todos); }
    function setEyeBreak(on: bool): void { if (loaded) { adapter.eyeBreak = on; lastBreak = Date.now(); } }
    function setEyeInterval(minutes: int): void { if (loaded && minutes >= 5 && minutes <= 120) adapter.eyeInterval = minutes; }

    // Clocks
    property var clocks: []
    property int clockViewers
    function refreshClocks(): void {
        if (clockProcess.running || !clocksConfig.length) return;
        clockProcess.command = ["sh", "-c", "for z in \"$@\"; do TZ=\"$z\" date +'%H:%M|%a|%H'; done", "sh", ...clocksConfig.map(c => c.tz)];
        clockProcess.running = true;
    }
    Process {
        id: clockProcess
        stdout: StdioCollector { onStreamFinished: root.clocks = Logic.parseClockOutput(text, root.clocksConfig) }
    }
    Timer { interval: 20000; repeat: true; running: root.clockViewers > 0; triggeredOnStart: true; onTriggered: root.refreshClocks() }

    // Eye breaks: a reminder after the interval, held back while busy.
    property double lastBreak: Date.now()
    readonly property bool busy: IslandLive.cameraActive || IslandLive.micActive || Recorder.running || IslandIdle.away
    signal eyeBreak
    Timer {
        interval: 30000; repeat: true; running: root.eyeBreakEnabled
        onTriggered: {
            if (!Logic.eyeBreakDue(root.lastBreak, Date.now(), root.eyeInterval, root.busy)) return;
            root.lastBreak = Date.now();
            root.eyeBreak();
        }
    }

    // Keep awake for a set time.
    property double awakeUntil
    property double now: Date.now()
    readonly property string awakeLeft: Logic.awakeLabel(awakeUntil, now)
    function keepAwake(minutes: int): void {
        IdleInhibitor.enabled = true;
        awakeUntil = Logic.awakeDeadline(Date.now(), minutes);
        awakeEnd.interval = Math.max(1000, awakeUntil - Date.now());
        awakeEnd.running = awakeUntil > 0;
    }
    function stopAwake(): void { awakeEnd.stop(); awakeUntil = 0; IdleInhibitor.enabled = false; }
    Timer { id: awakeEnd; onTriggered: { root.awakeUntil = 0; IdleInhibitor.enabled = false; } }
    Timer { interval: 30000; repeat: true; running: root.awakeUntil > 0; onTriggered: root.now = Date.now() }
    Connections {
        target: IdleInhibitor
        function onEnabledChanged(): void { if (!IdleInhibitor.enabled) { awakeEnd.stop(); root.awakeUntil = 0; } }
    }

    // Presentation: quiet notifications and no screen sleep together.
    property bool presenting
    property bool dndBefore
    property bool awakeBefore
    function setPresenting(on: bool): void {
        if (on === presenting) return;
        if (on) {
            dndBefore = Notifs.dnd; awakeBefore = IdleInhibitor.enabled;
            Notifs.dnd = true; IdleInhibitor.enabled = true;
        } else {
            Notifs.dnd = dndBefore; IdleInhibitor.enabled = awakeBefore;
        }
        presenting = on;
    }

    Timer { id: save; interval: 400; onTriggered: file.writeAdapter() }
    FileView {
        id: file
        path: `${Paths.state}/island-tools.json`
        atomicWrites: true
        printErrors: false
        onAdapterUpdated: save.restart()
        onLoaded: root.loaded = true
        onLoadFailed: error => { root.loaded = true; if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: adapter
            property string notes
            property var todos: []
            property var clocks: Logic.defaultClocks()
            property bool eyeBreak
            property int eyeInterval: 20
            property string petName: "Mochi"
            property int petKind: 0
            property bool agentNotch: true
            property bool glass
            property var musicExtras: ["back15", "fwd15", "shuffle", "loop"]
        }
    }
}
