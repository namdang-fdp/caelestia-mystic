.pragma library

// Pure helpers for the developer features: finished commands, ports, PR/CI
// changes, time per project and the standup draft.

// "45s", "2m 14s", "1h 05m"
function duration(seconds) {
    const s = Math.max(0, Math.round(Number(seconds) || 0));
    if (s < 60) return `${s}s`;
    const m = Math.floor(s / 60);
    if (m < 60) return `${m}m ${String(s % 60).padStart(2, "0")}s`;
    return `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, "0")}m`;
}

// One line of at most `max` characters, for the pill.
function oneLine(text, max) {
    const t = String(text || "").replace(/\s+/g, " ").trim();
    return t.length > max ? t.slice(0, max - 1) + "…" : t;
}

// What the pill says about a finished command.
function commandPill(code, seconds, command) {
    const failed = Number(code) !== 0;
    return {
        icon: failed ? "close" : "check",
        title: oneLine(command, 38) || "Terminal",
        detail: failed ? `exit ${Number(code)}` : duration(seconds),
        tint: failed ? "red" : "green"
    };
}

// Command lines arrive from the shell as IPC arguments: keep only sane numbers.
function validExit(code) {
    return Number.isInteger(code) && code >= 0 && code <= 255;
}

function validSeconds(seconds) {
    return Number.isFinite(seconds) && seconds >= 0 && seconds < 7 * 86400;
}

// ---- Pull requests -------------------------------------------------------

function prId(pr) {
    return `${pr.repo}#${pr.number}`;
}

// Compares the previous read with a new one. `previous` is null on the first
// read, which only records a baseline so a shell restart never floods pills.
// Returns { events, state }; events are { type, pr } with type one of
// "ci-failed", "ci-passed", "merged", "changes", "approved".
function diffPulls(previous, result) {
    const open = {};
    const events = [];
    for (const pr of Array.from((result && result.prs) || [])) {
        const id = prId(pr);
        open[id] = { ci: pr.ci, review: pr.review };
        const before = previous && previous.open ? previous.open[id] : null;
        if (!before) continue;
        if (before.ci !== pr.ci) {
            if (pr.ci === "failing") events.push({ type: "ci-failed", pr });
            else if (pr.ci === "passing" && before.ci !== "none") events.push({ type: "ci-passed", pr });
        }
        if (before.review !== pr.review) {
            if (pr.review === "CHANGES_REQUESTED") events.push({ type: "changes", pr });
            else if (pr.review === "APPROVED") events.push({ type: "approved", pr });
        }
    }
    const merged = Array.from((result && result.merged) || []).map(prId);
    const knownMerged = previous && previous.merged ? previous.merged : [];
    if (previous) {
        for (const m of Array.from(result.merged || [])) {
            const id = prId(m);
            if (previous.open && previous.open[id] && !knownMerged.includes(id)) events.push({ type: "merged", pr: m });
        }
    }
    return { events, state: { open, merged } };
}

var PULL_PILLS = {
    "ci-failed": { icon: "error", title: "CI failed", tint: "red" },
    "ci-passed": { icon: "check_circle", title: "CI passed", tint: "green" },
    "merged": { icon: "merge", title: "Merged", tint: "purple" },
    "changes": { icon: "rate_review", title: "Changes requested", tint: "orange" },
    "approved": { icon: "thumb_up", title: "Approved", tint: "green" }
};

function pullPill(event) {
    const pr = event.pr;
    const base = PULL_PILLS[event.type] || { icon: "merge", title: "Pull request", tint: "blue" };
    const where = `${pr.repo ? pr.repo.split("/").pop() : ""} #${pr.number}`;
    return { icon: base.icon, title: base.title, tint: base.tint, detail: `${where} · ${oneLine(pr.title, 34)}` };
}

// True when any open PR has failing checks: the mascot worries about it.
function anyFailing(result) {
    return Array.from((result && result.prs) || []).some(pr => pr.ci === "failing");
}
