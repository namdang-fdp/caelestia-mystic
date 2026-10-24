.pragma library

// Moves key to index `to` among the visible pins while keeping pins that are not
// shown (uninstalled apps) at their positions in the stored list.
function reorderPinned(all, visible, key, to) {
    const order = visible.filter(k => k !== key);
    if (order.length === visible.length)
        return all.slice();
    order.splice(Math.max(0, Math.min(to, order.length)), 0, key);
    let next = 0;
    return all.map(k => visible.includes(k) ? order[next++] : k);
}

// Slot a dragged icon lands in, given how far it moved from its own slot
function dropIndex(from, dx, slot, count) {
    if (count <= 0 || slot <= 0)
        return from;
    return Math.max(0, Math.min(count - 1, from + Math.round(dx / slot)));
}

// Horizontal shift for the icon at `index` while the pin at `from` is dragged to `to`
function dragShift(index, from, to, slot) {
    if (index < 0 || from < 0 || index === from)
        return 0;
    if (from < to && index > from && index <= to)
        return -slot;
    if (to < from && index >= to && index < from)
        return slot;
    return 0;
}

// Next window when cycling with the scroll wheel; `current` is -1 when none is focused
function cycleIndex(current, count, step) {
    if (count <= 0)
        return -1;
    if (current < 0)
        return step > 0 ? 0 : count - 1;
    return ((current + step) % count + count) % count;
}

function fileUrl(url) {
    return /^file:\/\//i.test(url);
}

function localPath(url) {
    if (!fileUrl(url))
        return url.startsWith("/") ? url : "";
    try {
        return decodeURIComponent(url.replace(/^file:\/\/[^/]*/i, ""));
    } catch (e) {
        return "";
    }
}

function asUrl(value) {
    if (/^[a-z][a-z0-9+.-]*:/i.test(value))
        return value;
    return "file://" + value.split("/").map(encodeURIComponent).join("/");
}

// Splits a desktop entry Exec value into arguments following the quoting rules of the
// desktop entry spec. Field codes are kept as literal tokens for expandExec.
function splitExec(exec) {
    const args = [];
    let cur = "";
    let started = false;
    let quoted = false;
    for (let i = 0; i < exec.length; i++) {
        const c = exec[i];
        if (quoted) {
            if (c === "\\" && i + 1 < exec.length && "\"`$\\".includes(exec[i + 1]))
                cur += exec[++i];
            else if (c === "\"")
                quoted = false;
            else
                cur += c;
        } else if (c === "\"") {
            quoted = true;
            started = true;
        } else if (c === " " || c === "\t" || c === "\n") {
            if (started)
                args.push(cur);
            cur = "";
            started = false;
        } else if (c === "\\" && i + 1 < exec.length) {
            cur += exec[++i];
            started = true;
        } else {
            cur += c;
            started = true;
        }
    }
    if (started)
        args.push(cur);
    return args;
}

// Builds the commands that open `urls` with a desktop entry Exec value. Apps that only
// take a single file (%f/%u) are started once per file, as the spec asks.
function expandExec(exec, urls, name, icon) {
    const args = splitExec(exec || "");
    if (args.length === 0)
        return [];

    const paths = urls.map(localPath).filter(p => p);
    const uris = urls.map(asUrl);
    const codes = args.join(" ").match(/%[fFuU]/g) ?? [];

    const expand = (files, fileUris) => {
        const out = [];
        for (const arg of args) {
            if (arg === "%F" || arg === "%U") {
                out.push(...(arg === "%F" ? files : fileUris));
                continue;
            }
            if (arg === "%i") {
                if (icon)
                    out.push("--icon", icon);
                continue;
            }
            let text = "";
            for (let i = 0; i < arg.length; i++) {
                if (arg[i] !== "%" || i + 1 >= arg.length) {
                    text += arg[i];
                    continue;
                }
                const code = arg[++i];
                if (code === "%")
                    text += "%";
                else if (code === "f" || code === "F")
                    text += files[0] ?? "";
                else if (code === "u" || code === "U")
                    text += fileUris[0] ?? "";
                else if (code === "c")
                    text += name ?? "";
                // Deprecated and unknown field codes expand to nothing
            }
            if (text !== "" || !/^%[a-zA-Z]$/.test(arg))
                out.push(text);
        }
        // Apps without file field codes still get the files appended
        if (codes.length === 0)
            out.push(...(paths.length === urls.length ? paths : uris));
        return out;
    };

    if (codes.length === 0 || codes.some(c => c === "%F" || c === "%U"))
        return [expand(paths, uris)];

    // Only %f or %u: one instance per file
    if (codes.includes("%f")) {
        if (paths.length <= 1)
            return [expand(paths, paths.map(asUrl))];
        return paths.map(path => expand([path], [asUrl(path)]));
    }
    if (uris.length <= 1)
        return [expand(paths, uris)];
    return uris.map(uri => expand(localPath(uri) ? [localPath(uri)] : [], [uri]));
}
