.pragma library

// Decisions behind the left-edge resources drawer: severity colours, sorting,
// formatting, the Claude/Codex rows, and when the pointer should open it.

const WARM = { ram: 0.70, cpu: 0.70, swap: Infinity };
const HOT = { ram: 0.85, cpu: 0.90, swap: 0.5 };

function severity(kind, value) {
    if (!Number.isFinite(value) || !(kind in HOT)) return "ok";
    if (value >= HOT[kind]) return "hot";
    return value >= WARM[kind] ? "warm" : "ok";
}

function fraction(used, total) {
    return total > 0 ? used / total : 0;
}

function sortGroups(groups, key) {
    const field = key === "cpu" ? "cpu_percent" : "ram_kb";
    return Array.from(groups || []).sort((a, b) => b[field] - a[field] || String(a.name).localeCompare(String(b.name)));
}

function formatKb(kb) {
    if (kb < 1024) return Math.round(kb) + " kB";
    if (kb < 1048576) return Math.round(kb / 1024) + " MB";
    return (kb / 1048576).toFixed(1) + " GB";
}

function formatAge(seconds) {
    if (seconds < 60) return Math.floor(seconds) + "s";
    if (seconds < 3600) return Math.floor(seconds / 60) + "m";
    if (seconds < 86400) return Math.floor(seconds / 3600) + "h";
    return Math.floor(seconds / 86400) + "d";
}

function baseName(path) {
    return String(path || "").split("/").filter(Boolean).pop() || "";
}

// Rows for the Agents section. A Claude process is joined to its hook session
// by pid, else by cwd only when no other process shares that cwd, so two
// processes in one folder never borrow each other's state.
function agentRows(claude, sessions, groups, now) {
    const at = now === undefined ? Date.now() : now;
    const procs = Array.from(claude || []);
    const all = Array.from(sessions || []);
    const claudeSessions = all.filter(s => s.agent === "claude");
    const rows = procs.map(p => {
        let session = p.pid > 0 ? claudeSessions.find(s => s.pid === p.pid) : undefined;
        if (!session && procs.filter(q => q.cwd === p.cwd).length === 1) {
            const free = claudeSessions.filter(s => s.cwd === p.cwd && !procs.some(q => q.pid === s.pid));
            if (free.length === 1) session = free[0];
        }
        return {
            kind: "claude", label: p.project || baseName(p.cwd) || "claude",
            state: session ? session.state : "idle", age_s: p.age_s, ram_kb: p.ram_kb,
            orphan: !!p.orphan, aggregate: false, pid: p.pid, start: p.start || 0,
        };
    });
    for (const s of all.filter(x => x.agent === "codex")) {
        rows.push({
            kind: "codex", label: s.project || baseName(s.cwd) || "codex", state: s.state,
            age_s: Math.max(0, Math.round((at - Number(s.updated) * 1000) / 1000)),
            ram_kb: 0, orphan: false, aggregate: false, pid: 0, start: 0,
        });
    }
    const codex = Array.from(groups || []).find(g => g.name === "Codex");
    if (codex) {
        rows.push({ kind: "codex", label: "Codex", state: "", age_s: 0, ram_kb: codex.ram_kb, orphan: false, aggregate: true, pid: 0, start: 0 });
    }
    return rows;
}

// True only for a plain pointer resting on the left strip, inside the vertical
// band: never with a button held (dragging along the edge) or in fullscreen.
function triggerActive(p) {
    if (p.pressed || p.fullscreen) return false;
    return p.x <= p.strip && p.y >= p.bandStart * p.height && p.y <= p.bandEnd * p.height;
}

function inPanel(x, y, left, width, top, height, slack) {
    return x >= left - slack && x <= left + width + slack && y >= top - slack && y <= top + height + slack;
}

// ---- v2: history, alerts, attention, confirmation -------------------------

function kbField(text, key) {
    const m = new RegExp("^" + key + ":\\s+(\\d+)", "m").exec(String(text || ""));
    return m ? parseInt(m[1], 10) : 0;
}

function parseMeminfo(text) {
    return {
        total_kb: kbField(text, "MemTotal"), available_kb: kbField(text, "MemAvailable"),
        swap_total_kb: kbField(text, "SwapTotal"), swap_free_kb: kbField(text, "SwapFree"),
    };
}

// First "cpu" line of /proc/stat. idle counts idle + iowait.
function parseCpuStat(text) {
    const line = String(text || "").split("\n").find(l => /^cpu\s/.test(l));
    if (!line) return { total: 0, idle: 0 };
    const p = line.trim().split(/\s+/).slice(1, 9).map(Number);
    if (p.length < 5 || p.some(n => !Number.isFinite(n))) return { total: 0, idle: 0 };
    return { total: p.reduce((a, b) => a + b, 0), idle: p[3] + p[4] };
}

function cpuPercent(prev, cur) {
    if (!prev || !cur) return 0;
    const dt = cur.total - prev.total;
    if (!(dt > 0)) return 0;
    return Math.max(0, Math.min(100, (1 - (cur.idle - prev.idle) / dt) * 100));
}

function ring(list, value, max) {
    const v = Number.isFinite(value) ? value : 0;
    return Array.from(list || []).concat([v]).slice(-max);
}

function sparkPoints(values, width, height, ceiling) {
    const list = Array.from(values || []);
    const top = ceiling > 0 ? ceiling : 100;
    return list.map((v, i) => {
        const f = Math.max(0, Math.min(1, (Number.isFinite(v) ? v : 0) / top));
        return { x: list.length === 1 ? width : i * (width / (list.length - 1)), y: height - f * height };
    });
}

const ALERT = { ram: 0.85, swap: 0.5, need: 3, cooldownMs: 30 * 60 * 1000 };

// A kind alerts after `need` consecutive hot samples, then stays quiet for the cooldown.
// At most one kind fires per call (RAM first); the other waits for the next sample.
function alertStep(state, sample, nowMs) {
    const next = {};
    const hot = { ram: sample.ramFrac >= ALERT.ram, swap: sample.swapFrac >= ALERT.swap };
    for (const kind of ["ram", "swap"]) {
        const prev = (state && state[kind]) || { streak: 0, last: null };
        next[kind] = { streak: hot[kind] ? prev.streak + 1 : 0, last: prev.last };
    }
    let fire = null;
    for (const kind of ["ram", "swap"]) {
        const s = next[kind];
        if (s.streak >= ALERT.need && (s.last === null || nowMs - s.last >= ALERT.cooldownMs)) {
            s.last = nowMs;
            fire = kind;
            break;
        }
    }
    return { state: next, fire: fire };
}

function alertText(kind, fraction, topGroup) {
    const percent = Math.round(fraction * 100) + "% in use";
    return {
        title: kind === "ram" ? "Memory is high" : "Swap is high",
        body: percent + (topGroup ? ". Biggest: " + topGroup + "." : "."),
    };
}

// The one thing the Overview banner should point at, or null when all is well.
function attention(fracs, rows) {
    const hot = fracs.ram >= 0.85;
    const warm = !hot && (fracs.ram >= 0.70 || fracs.swap >= 0.5);
    if (!hot && !warm) return null;
    const idle = Array.from(rows || []).filter(r => r.kind === "claude" && (r.state === "idle" || r.state === ""));
    const held = idle.reduce((sum, r) => sum + r.ram_kb, 0);
    const base = hot ? "Memory is high" : (fracs.ram >= 0.70 ? "Memory is getting full" : "Swap is under pressure");
    if (held >= 200 * 1024) {
        return { level: hot ? "hot" : "warm", tab: "agents", text: base + " — " + idle.length + " idle agent sessions use " + formatKb(held) };
    }
    return { level: hot ? "hot" : "warm", tab: "processes", text: base };
}

// Two-step confirmation: the first click arms a key for windowMs, the second fires.
function confirmClick(armed, key, nowMs, windowMs) {
    if (armed && armed.key === key && nowMs < armed.until) return { fire: true, armed: null };
    return { fire: false, armed: { key: key, until: nowMs + windowMs } };
}

function orphanTargets(claude) {
    return Array.from(claude || []).filter(p => p.orphan).map(p => ({ pid: p.pid, start: p.start }));
}

const PROTECTED = ["Hyprland", "hyprland", "quickshell", "qs", "systemd", "pipewire", "pipewire-pulse", "wireplumber", "dbus-daemon", "dbus-broker", "Xwayland"];

function isProtected(name) {
    return PROTECTED.indexOf(String(name)) >= 0;
}
