.pragma library

// Media page extras and the fullscreen music show.

var EXTRAS = ["back15", "fwd15", "shuffle", "loop"];
var EXTRA_INFO = {
    back15: { icon: "replay_10", label: "Back 15 seconds" },
    fwd15: { icon: "forward_10", label: "Forward 15 seconds" },
    shuffle: { icon: "shuffle", label: "Shuffle" },
    loop: { icon: "repeat", label: "Repeat" }
};

function list(value) {
    return value && typeof value !== "string" && typeof value.length === "number" ? Array.from(value) : [];
}

// Saved choice of extra buttons, in canonical order, unknown ids dropped.
function extras(saved) {
    const chosen = list(saved);
    return EXTRAS.filter(id => chosen.includes(id));
}

function toggleExtra(saved, id) {
    if (!EXTRAS.includes(id)) return extras(saved);
    const chosen = extras(saved);
    return EXTRAS.filter(e => e === id ? !chosen.includes(id) : chosen.includes(e));
}

// New playback position in seconds after a relative seek, kept inside the track.
function seekTarget(position, length, delta) {
    const p = Number(position) + Number(delta);
    const max = Number.isFinite(length) && length > 0 ? length : Infinity;
    return Number.isFinite(p) ? Math.max(0, Math.min(p, max)) : 0;
}

// MPRIS loop states cycle None -> Track -> Playlist -> None (0, 1, 2).
function nextLoop(state) {
    return (Number(state) + 1) % 3;
}

function loopIcon(state) {
    return Number(state) === 1 ? "repeat_one" : "repeat";
}

// The lines around the current one, for the show: [{text, offset}].
function lyricWindow(lines, index, before, after) {
    const all = list(lines);
    if (!all.length || index < 0) return [];
    const result = [];
    for (let o = -before; o <= after; o++) {
        const i = index + o;
        if (i >= 0 && i < all.length) result.push({ text: all[i], offset: o });
    }
    return result;
}

var THEMES = [
    { id: "midnight", name: "Midnight", from: "#0a0a12", to: "#1c1c2e", accent: "#0a84ff" },
    { id: "sunset", name: "Sunset", from: "#2a0f1d", to: "#5c1f2e", accent: "#ff9f0a" },
    { id: "aurora", name: "Aurora", from: "#06191a", to: "#0b3b36", accent: "#30d158" },
    { id: "violet", name: "Violet", from: "#150b24", to: "#35195c", accent: "#bf5af2" },
    { id: "mono", name: "Mono", from: "#000000", to: "#1c1c1e", accent: "#ffffff" }
];

function theme(index) {
    const n = Number(index);
    return THEMES[Number.isInteger(n) && n >= 0 ? n % THEMES.length : 0];
}
