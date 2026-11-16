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
            orphan: !!p.orphan, aggregate: false,
        };
    });
    for (const s of all.filter(x => x.agent === "codex")) {
        rows.push({
            kind: "codex", label: s.project || baseName(s.cwd) || "codex", state: s.state,
            age_s: Math.max(0, Math.round((at - Number(s.updated) * 1000) / 1000)),
            ram_kb: 0, orphan: false, aggregate: false,
        });
    }
    const codex = Array.from(groups || []).find(g => g.name === "Codex");
    if (codex) {
        rows.push({ kind: "codex", label: "Codex", state: "", age_s: 0, ram_kb: codex.ram_kb, orphan: false, aggregate: true });
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
