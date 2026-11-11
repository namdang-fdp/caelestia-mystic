.pragma library

// Pure helpers for the island tools: todos, keep-awake timing, eye breaks,
// box breathing and world clocks.

function list(value) {
    return value && typeof value !== "string" && typeof value.length === "number" ? Array.from(value) : [];
}

var MAX_TODOS = 50;
var MAX_TODO_LENGTH = 120;

function addTodo(todos, text, id) {
    const value = String(text || "").trim().slice(0, MAX_TODO_LENGTH);
    const current = list(todos);
    if (!value || current.length >= MAX_TODOS) return current;
    return [...current, { id: String(id), text: value, done: false }];
}

function toggleTodo(todos, id) {
    return list(todos).map(t => t.id === id ? { id: t.id, text: t.text, done: !t.done } : t);
}

function removeTodo(todos, id) {
    return list(todos).filter(t => t.id !== id);
}

function clearDone(todos) {
    return list(todos).filter(t => !t.done);
}

function openCount(todos) {
    return list(todos).filter(t => !t.done).length;
}

// Open items first, finished ones after, each keeping its order.
function sortedTodos(todos) {
    const all = list(todos);
    return [...all.filter(t => !t.done), ...all.filter(t => t.done)];
}

// Keep-awake choices in minutes; 0 means until turned off.
var AWAKE_CHOICES = [30, 60, 120, 0];

function awakeDeadline(now, minutes) {
    return minutes > 0 ? now + minutes * 60000 : 0;
}

function awakeLabel(deadline, now) {
    if (!deadline) return "";
    const mins = Math.max(0, Math.ceil((deadline - now) / 60000));
    return mins >= 60 ? `${Math.floor(mins / 60)}h ${String(mins % 60).padStart(2, "0")}m` : `${mins}m`;
}

// An eye break is due after the interval, but never while the user is busy
// (call, recording, away or presenting): it waits for the next quiet minute.
function eyeBreakDue(lastAt, now, intervalMinutes, busy) {
    return !busy && now - lastAt >= intervalMinutes * 60000;
}

// Box breathing: inhale, hold, exhale, hold, equal length. `scale` is the
// size of the breathing circle between 0.55 and 1.
var PHASES = ["inhale", "hold", "exhale", "rest"];
function breathe(elapsedMs, phaseMs) {
    const length = phaseMs > 0 ? phaseMs : 4000;
    const total = length * 4;
    const t = ((elapsedMs % total) + total) % total;
    const index = Math.floor(t / length);
    const progress = (t - index * length) / length;
    const ease = x => x * x * (3 - 2 * x);
    const scale = index === 0 ? .55 + .45 * ease(progress) : index === 1 ? 1 : index === 2 ? 1 - .45 * ease(progress) : .55;
    return { phase: PHASES[index], progress: progress, scale: scale, secondsLeft: Math.ceil((length - progress * length) / 1000) };
}

var CLOCK_ZONES = /^[A-Za-z0-9_+\-]+(\/[A-Za-z0-9_+\-]+){0,2}$/;

function validZone(tz) {
    return typeof tz === "string" && CLOCK_ZONES.test(tz);
}

function defaultClocks() {
    return [{ name: "Hanoi", tz: "Asia/Ho_Chi_Minh" }, { name: "Tokyo", tz: "Asia/Tokyo" }, { name: "New York", tz: "America/New_York" }];
}

// Output of `TZ=<zone> date +%H:%M|%a|%H` lines, matched to the clocks in order.
function parseClockOutput(text, clocks) {
    const lines = String(text || "").split("\n").filter(l => l.includes("|"));
    return list(clocks).map((c, i) => {
        const [time, day, hour] = (lines[i] || "").split("|");
        const h = Number(hour);
        return { name: c.name, tz: c.tz, time: time || "--:--", day: day || "", night: Number.isFinite(h) ? h < 6 || h >= 19 : false };
    });
}
