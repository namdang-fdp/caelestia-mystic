.pragma library

// Agent sessions are small JSON files written by agent_hook.py. This file
// decides which of them still count, which one the notch shows, and what
// changed between two reads.

var STALE = { working: 10 * 60 * 1000, waiting: 30 * 60 * 1000, done: 3 * 60 * 1000 };
var PRIORITY = { waiting: 3, working: 2, done: 1 };
var NAMES = { claude: "Claude Code", codex: "Codex", gemini: "Gemini CLI", cursor: "Cursor", windsurf: "Windsurf", copilot: "Copilot CLI", droid: "Factory Droid", grok: "Grok Build" };

function agentName(key) {
    return NAMES[key] || (typeof key === "string" && key ? key.charAt(0).toUpperCase() + key.slice(1) : "Agent");
}

function valid(s) {
    return !!s && typeof s === "object" && typeof s.agent === "string" && typeof s.session === "string"
        && PRIORITY[s.state] > 0 && Number.isFinite(Number(s.updated));
}

// Sessions that are still current. A session that stops reporting is
// dropped after a while so the notch never stays busy forever.
function live(sessions, now) {
    return Array.from(sessions || []).filter(valid)
        .filter(s => now - Number(s.updated) * 1000 <= STALE[s.state])
        .sort((a, b) => PRIORITY[b.state] - PRIORITY[a.state] || Number(b.updated) - Number(a.updated));
}

// "waiting", "working" or "" — done sessions never claim the notch.
function foreground(sessions, now) {
    const first = live(sessions, now)[0];
    return first && first.state !== "done" ? first.state : "";
}

function primary(sessions, now) {
    const first = live(sessions, now).filter(s => s.state !== "done")[0];
    return first || null;
}

function busyCount(sessions, now) {
    return live(sessions, now).filter(s => s.state !== "done").length;
}

// Compares session states with the previous read. Returns the sessions that
// just started waiting or finished, and the new state map.
function diff(previous, sessions, now) {
    const states = {};
    const events = [];
    for (const s of live(sessions, now)) {
        const id = `${s.agent}:${s.session}`;
        states[id] = s.state;
        const before = previous ? previous[id] : undefined;
        if (before === s.state) continue;
        if (s.state === "waiting") events.push({ type: "waiting", session: s });
        else if (s.state === "done" && before === "working") events.push({ type: "done", session: s });
    }
    return { events: events, states: states };
}

function stateLabel(state) {
    return ({ waiting: "Needs you", working: "Working", done: "Done" })[state] || "";
}

// "2m", "1h 05m"; used for how long a session has been in its state.
function elapsed(seconds) {
    const s = Math.max(0, Math.floor(seconds));
    if (s < 60) return `${s}s`;
    const m = Math.floor(s / 60);
    return m < 60 ? `${m}m` : `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, "0")}m`;
}

// 12400 -> "12.4K", 2300000 -> "2.3M"
function compact(n) {
    const v = Number(n);
    if (!Number.isFinite(v) || v < 0) return "0";
    if (v < 1000) return String(Math.round(v));
    if (v < 1e6) return `${(v / 1e3).toFixed(v < 1e4 ? 1 : 0)}K`;
    return `${(v / 1e6).toFixed(v < 1e7 ? 1 : 0)}M`;
}

// Bar heights (0..1) for a 7-day series, relative to the busiest day.
function bars(days) {
    const list = Array.from(days || []);
    const max = Math.max(1, ...list.map(d => Number(d.tokens) || 0));
    return list.map(d => (Number(d.tokens) || 0) / max);
}

// "ok" below 70% used, "warn" to 90%, then "high".
function severity(percent) {
    const p = Number(percent);
    return !Number.isFinite(p) || p < 70 ? "ok" : p < 90 ? "warn" : "high";
}

function clampPercent(percent) {
    const p = Number(percent);
    return Number.isFinite(p) ? Math.max(0, Math.min(100, Math.round(p))) : 0;
}

// The mascot's mood follows what the agents are doing and how much quota is left.
function petMood(foreground, peakPercent) {
    if (foreground === "waiting") return "waiting";
    if (Number(peakPercent) >= 90) return "tired";
    return foreground === "working" ? "working" : "idle";
}

function moodLabel(mood) {
    return ({ working: "Hyped", waiting: "Needs you", tired: "Exhausted", idle: "Chill" })[mood] || "Chill";
}

// 0..100, how fresh the pet feels: the opposite of the heaviest quota in use.
function health(peakPercent) {
    return 100 - clampPercent(peakPercent);
}

// Highest quota use across the agents that report one, or 0.
function peakPercent(values) {
    return Math.max(0, ...Array.from(values || []).map(Number).filter(Number.isFinite));
}

// Adds the per-day token series of several agents.
function sumWeeks(weeks) {
    const lists = Array.from(weeks || []).filter(w => w && w.length);
    if (!lists.length) return [];
    return Array.from(lists[0]).map((d, i) => ({
        date: d.date,
        tokens: lists.reduce((sum, w) => sum + (Number(w[i] && w[i].tokens) || 0), 0),
        calls: lists.reduce((sum, w) => sum + (Number(w[i] && w[i].calls) || 0), 0),
    }));
}
