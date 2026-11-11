.pragma library

var modules = ["media", "timer", "agent", "battery", "notes", "shelf"];

// JsonAdapter restores QML sequences, which have length/iteration but fail Array.isArray.
function list(value) {
    return value && typeof value !== "string" && typeof value.length === "number" ? Array.from(value) : [];
}

function order(saved) {
    return [...new Set([...list(saved), ...modules])].filter(id => modules.includes(id));
}

function move(saved, id, direction) {
    const next = order(saved), index = next.indexOf(id), target = index + direction;
    if (index >= 0 && (direction === -1 || direction === 1) && target >= 0 && target < next.length)
        [next[index], next[target]] = [next[target], next[index]];
    return next;
}

// Moves a card to an absolute position, clamped to the list.
function moveTo(saved, id, index) {
    const next = order(saved), from = next.indexOf(id);
    if (from < 0 || !Number.isInteger(index)) return next;
    const to = Math.max(0, Math.min(next.length - 1, index));
    next.splice(from, 1);
    next.splice(to, 0, id);
    return next;
}

function visible(saved, disabled, hasShelf, showMedia, hasAgent) {
    const hidden = list(disabled);
    return order(saved).filter(id => !hidden.includes(id) && (id !== "shelf" || hasShelf) && (id !== "media" || showMedia) && (id !== "agent" || hasAgent));
}
