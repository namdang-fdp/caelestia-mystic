.pragma library

// Decisions behind the island's smaller live activities.

// Connectivity transitions worth announcing. Unknown/portal states are
// ignored so startup and captive portals do not cause noise.
function networkChange(previous, next) {
    const up = v => v === "full";
    const down = v => v === "none" || v === "limited";
    if (up(previous) && down(next)) return next === "none" ? "offline" : "limited";
    if (down(previous) && up(next)) return "online";
    return "";
}

// Download folder entries that mean "a file just finished". Partial files
// and hidden files are not downloads yet.
var PARTIAL = [".part", ".crdownload", ".download", ".tmp", ".opdownload", ".aria2", ".!qB"];
function downloadName(name) {
    const n = String(name || "").trim();
    if (!n || n.startsWith(".") || n.includes("/")) return "";
    const lower = n.toLowerCase();
    return PARTIAL.some(s => lower.endsWith(s.toLowerCase())) ? "" : n;
}

// Suppresses bursts, such as an archive being unpacked into the folder.
function allowEvent(lastAt, now, gapMs) {
    return !Number.isFinite(lastAt) || now - lastAt >= gapMs;
}

// A recording stream from an app, not the shell's own level meter or an
// internal bluetooth capture node.
function isAppRecording(props) {
    if (!props) return false;
    if (props["media.class"] !== "Stream/Input/Audio") return false;
    if (props["stream.capture.sink"] === "true" || props["stream.capture.sink"] === true) return false;
    const app = String(props["application.name"] || "").toLowerCase();
    return !(app.includes("quickshell") || app.includes("peak detect") || app.includes("cava"));
}

// A camera consumer: a PipeWire video input stream from an app.
function isCameraStream(props) {
    return !!props && String(props["media.class"] || "").startsWith("Stream/Input/Video");
}

function capsText(on) {
    return on ? "Caps Lock on" : "Caps Lock off";
}

// sysfs LED brightness lines, one per keyboard: any lit LED means caps lock is on.
function capsOn(values) {
    return Array.from(values || []).some(v => Number(v) > 0);
}

// Each kind of feedback gets its own colour, named after IslandTheme.palette.
var TINTS = {
    volume_up: "blue", volume_down: "blue", volume_mute: "blue", volume_off: "red",
    brightness_6: "yellow", mic: "orange", mic_off: "red",
    bolt: "green", battery_full: "green", power_off: "orange",
    grid_view: "indigo", music_note: "pink", alarm: "orange",
    front_hand: "orange", task_alt: "green", download_done: "blue",
    content_copy: "teal", pause_circle: "orange", keyboard_capslock: "orange",
    wifi: "green", wifi_off: "red", visibility: "green", headphones: "blue",
    speaker: "blue", mouse: "teal", keyboard: "teal", sports_esports: "purple",
    smartphone: "teal", bluetooth: "blue", lyrics: "pink", schedule: "indigo"
};

function iconTint(icon) {
    return TINTS[icon] || "blue";
}
