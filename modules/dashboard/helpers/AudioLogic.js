.pragma library

// Quickshell reports cbrt(sample) / volume, so this only rejects digital silence (about 1e-12 linear), not -80 dB.
// Keep brief pauses between words from blinking.
function audibleUntil(previous, peak, eligible, now) {
    if (!eligible) return 0;
    if (Number.isFinite(peak) && peak > .0001) return now + 1200;
    return previous > now ? previous : 0;
}

// Browsers destroy and recreate their playback stream on every seek (a new node, so a new watcher with no history).
const CARRY_MS = 1500;

function streamKey(properties) {
    return String(properties["application.process.id"] || properties["application.process.binary"] || properties["application.name"] || properties["node.name"] || "");
}

// `held` maps key -> { stream, until }. `current` lists the streams audible this tick as { key, stream }.
// A stream that vanished keeps counting for CARRY_MS unless it was deliberately silenced (mute or zero volume,
// listed in `silenced`) or the whole output was (`clearAll`).
function carryOver(held, current, silenced, clearAll, now) {
    const next = {};
    const streams = current.map(entry => entry.stream);
    const present = new Set(current.map(entry => entry.key));
    current.forEach(entry => { next[entry.key] = { stream: entry.stream, until: now + CARRY_MS }; });
    if (!clearAll) {
        for (const key of Object.keys(held)) {
            if (present.has(key) || silenced.includes(key) || !(held[key].until > now)) continue;
            next[key] = held[key];
            streams.push(held[key].stream);
        }
    }
    return { held: next, streams: streams };
}

function streamLabel(properties) {
    const app = properties["application.name"] || properties["application.process.binary"] || "";
    const media = properties["media.title"] || properties["media.name"] || "";
    const generic = /^(audiostream|audio stream|playback|audio|output|stream)$/i.test(media);
    return media && !generic && media !== app ? [media, app].filter(Boolean).join(" · ") : app;
}

function matchesPlayer(player, properties) {
    if (!player?.isPlaying || !player.trackTitle) return false;
    function normalize(value) {
        return String(value || "").toLowerCase().replace(/\.desktop$/, "").replace(/-bin$/, "");
    }
    const names = [properties["application.name"], properties["application.id"], properties["application.process.binary"]].map(normalize).filter(Boolean);
    return [player.identity, player.desktopEntry].map(normalize).filter(Boolean).some(name => names.includes(name));
}
