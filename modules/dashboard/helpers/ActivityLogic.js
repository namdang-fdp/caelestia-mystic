.pragma library

function remaining(deadline, now) {
    return Math.max(0, deadline - now);
}

function timerRemaining(running, deadline, saved, now) {
    return running ? remaining(deadline, now) : saved;
}

function durationMinutes(value) {
    const n = Number(value);
    return value !== null && Number.isInteger(n) && n >= 1 && n <= 180 ? n : 0;
}

function nextPhase(phase, completed) {
    return phase === "focus" ? completed % 4 === 0 ? "longBreak" : "break" : "focus";
}

function batteryLevel(present, onBattery, fraction) {
    if (!present || !onBattery || typeof fraction !== "number" || !Number.isFinite(fraction) || fraction < 0 || fraction > 1)
        return 0;
    return fraction <= .1 ? 2 : fraction <= .2 ? 1 : 0;
}

function temperatureState(temperature, samples, active) {
    if (typeof temperature !== "number" || !Number.isFinite(temperature) || temperature <= 0 || temperature > 125)
        return { samples: 0, active: false };
    const count = temperature >= 90 ? samples + 1 : 0;
    return { samples: Math.min(count, 2), active: active ? temperature >= 85 : count >= 2 };
}

function clock(seconds) {
    const s = Math.max(0, Math.ceil(seconds));
    return `${Math.floor(s / 60).toString().padStart(2, "0")}:${(s % 60).toString().padStart(2, "0")}`;
}

// Accumulates wheel/touchpad deltas (120 units = one notch) into whole steps.
function wheelSteps(accumulated, delta) {
    const total = accumulated + (Number.isFinite(delta) ? delta : 0);
    const steps = total >= 0 ? Math.floor(total / 120) : Math.ceil(total / 120);
    return { steps: steps, rest: total - steps * 120 };
}

function clampUnit(value) {
    return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0;
}

// Cycles the resting pill between the modes that currently have content.
function nextRestingMode(current, available, direction) {
    if (!available.length) return "auto";
    const index = available.indexOf(current);
    if (index < 0) return available[direction < 0 ? available.length - 1 : 0];
    return available[(index + (direction < 0 ? available.length - 1 : 1)) % available.length];
}

// Maps freedesktop Bluetooth device icon names to Material Symbols.
function bluetoothIcon(icon) {
    const name = typeof icon === "string" ? icon : "";
    if (name.includes("headset") || name.includes("headphone")) return "headphones";
    if (name.includes("audio")) return "speaker";
    if (name.includes("mouse")) return "mouse";
    if (name.includes("keyboard")) return "keyboard";
    if (name.includes("gaming") || name.includes("joystick")) return "sports_esports";
    if (name.includes("phone")) return "smartphone";
    if (name.includes("computer")) return "computer";
    if (name.includes("video") || name.includes("display")) return "tv";
    if (name.includes("watch")) return "watch";
    return "bluetooth";
}

// Shelf sizes: "812 B", "2.4 MB", "15 MB".
function formatBytes(bytes) {
    if (!Number.isFinite(bytes) || bytes < 0) return "";
    const units = ["B", "KB", "MB", "GB", "TB"];
    let value = bytes;
    let unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
        value /= 1024;
        unit++;
    }
    return `${unit && value < 10 ? value.toFixed(1) : Math.round(value)} ${units[unit]}`;
}

// Text tag shown instead of a file-type icon.
function fileKind(name, isDir) {
    if (isDir) return "Folder";
    const dot = name.lastIndexOf(".");
    return dot > 0 && dot < name.length - 1 ? name.slice(dot + 1).toUpperCase() : "File";
}

// Dropped file:// URLs as decoded local paths; anything else is ignored.
function localPaths(urls) {
    const paths = [];
    for (const url of urls ?? []) {
        const text = String(url);
        if (!text.startsWith("file://")) continue;
        try {
            paths.push(decodeURIComponent(text.slice(7)));
        } catch (_) {}
    }
    return paths;
}

// Newest drops first; re-dropping a shelved path moves it to the front.
function shelfMerge(existing, incoming, limit) {
    const seen = new Set();
    const merged = [];
    for (const item of [...incoming, ...(existing ?? [])]) {
        if (seen.has(item.path)) continue;
        seen.add(item.path);
        merged.push(item);
    }
    return merged.slice(0, limit);
}

// Idle companion timing, driven by Math.random() in QML.
function blinkDelay(random) {
    return 2600 + Math.floor(random * 3600);
}

function isDoubleBlink(random) {
    return random < .18;
}

function nextGlance(current, random) {
    const options = [-1, -.5, 0, .5, 1].filter(v => v !== current);
    return options[Math.min(options.length - 1, Math.floor(random * options.length))];
}
