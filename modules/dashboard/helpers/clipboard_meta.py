#!/usr/bin/env python3
"""Per-entry details for cliphist: which app a copy came from, and when.

cliphist keeps neither, so the island records them as copies happen:

    clipboard_meta.py tag [app]     remember the newest entry's app (default: focused window) and time
    clipboard_meta.py drop-latest   delete the newest entry (recording paused)
    clipboard_meta.py prune <hours> delete tagged entries older than that
    clipboard_meta.py wipe          delete the whole cliphist history (pinned items stay)
    clipboard_meta.py meta          print the saved details

Only the window class and a timestamp are stored, never clipboard content.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ID = re.compile(r"[0-9]+")
APP = re.compile(r"[^\w .+@:-]")


def meta_path():
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local/state")
    return Path(base) / "caelestia" / "island-clipboard-meta.json"


def load(path=None):
    try:
        data = json.loads((path or meta_path()).read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save(data, path=None):
    path = path or meta_path()
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    handle, temporary = tempfile.mkstemp(dir=path.parent, prefix=".tmp-")
    try:
        with os.fdopen(handle, "w") as stream:
            json.dump(data, stream)
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def clean_app(value):
    return APP.sub("", str(value or "")).strip()[:48]


def present_ids(listing):
    return [line.partition("\t")[0] for line in listing.splitlines() if ID.fullmatch(line.partition("\t")[0])]


def expired(meta, now, hours, present):
    """Ids tagged more than `hours` ago that still exist in cliphist."""
    if hours <= 0:
        return []
    limit = now - hours * 3600
    return [i for i, m in meta.items() if i in present and isinstance(m, dict) and float(m.get("t", now)) < limit]


def forget_missing(meta, present):
    return {i: m for i, m in meta.items() if i in present}


def active_window_class():
    try:
        out = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, timeout=3, check=False).stdout
        return clean_app(json.loads(out).get("class", ""))
    except Exception:
        return ""


def cliphist(*args, data=None):
    return subprocess.run(["cliphist", *args], input=data, capture_output=True, timeout=15, check=False)


def main(argv):
    action = argv[1] if len(argv) > 1 else "meta"
    if action == "meta":
        return {"meta": load()}
    listing = cliphist("list").stdout.decode("utf-8", "replace")
    ids = present_ids(listing)
    meta = forget_missing(load(), set(ids))
    if action == "tag":
        if ids:
            app = clean_app(argv[2] if len(argv) > 2 else "") or active_window_class()
            meta[ids[0]] = {"app": app, "t": time.time()}
        save(meta)
        return {"id": ids[0] if ids else ""}
    if action == "drop-latest":
        if ids:
            cliphist("delete", data=(ids[0] + "\t").encode())
            meta.pop(ids[0], None)
        save(meta)
        return {"ok": True}
    if action == "wipe":
        result = cliphist("wipe")
        if result.returncode:
            raise RuntimeError("Could not clear the clipboard history")
        save({})
        return {"ok": True, "removed": len(ids)}
    if action == "prune":
        hours = float(argv[2]) if len(argv) > 2 else 0
        removed = expired(meta, time.time(), hours, set(ids))
        for item in removed:
            cliphist("delete", data=(item + "\t").encode())
            meta.pop(item, None)
        save(meta)
        return {"removed": len(removed)}
    raise ValueError("unknown action")


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv)))
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
