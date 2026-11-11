.pragma library

// Search with @tags: "@image", "@link", "@code", "@text", "@pinned" filter by
// kind; any other "@name" filters by the app the text was copied from.
var KINDS = { image: "image", images: "image", img: "image", link: "link", links: "link", url: "link", code: "code", text: "text", pinned: "pinned", pin: "pinned" };

function parseQuery(text) {
    const kinds = [], apps = [], words = [];
    for (const part of String(text || "").toLowerCase().split(/\s+/).filter(p => p)) {
        if (part.length > 1 && part.startsWith("@")) {
            const tag = part.slice(1);
            if (KINDS[tag]) kinds.push(KINDS[tag]);
            else apps.push(tag);
        } else words.push(part);
    }
    return { kinds: kinds, apps: apps, words: words };
}

function matches(entry, query) {
    const label = String(entry.label || "").toLowerCase();
    const app = String(entry.app || "").toLowerCase();
    return query.kinds.every(k => k === "pinned" ? !!entry.pinned : entry.type === k)
        && query.apps.every(a => app.includes(a))
        && query.words.every(w => label.includes(w));
}

var RETENTION = [0, 1, 24, 168];

function nextRetention(hours) {
    const i = RETENTION.indexOf(hours);
    return RETENTION[(i + 1) % RETENTION.length];
}

function retentionLabel(hours) {
    return hours === 0 ? "Auto-delete off" : hours < 24 ? `Delete after ${hours} hour` : hours === 24 ? "Delete after 1 day" : "Delete after 7 days";
}

// Copy Stack: entries leave in the order they were copied.
function pushStack(stack, id) {
    const list = Array.from(stack || []);
    return id && !list.includes(id) ? [...list, id] : list;
}

function popStack(stack) {
    const list = Array.from(stack || []);
    return { next: list[0] || "", rest: list.slice(1) };
}
