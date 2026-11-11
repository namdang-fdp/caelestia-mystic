#!/usr/bin/env python3
"""Small argument-only bridge to the user's existing cliphist database."""
import json
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ID = re.compile(r"[0-9]+")
PIN_ID = re.compile(r"p[0-9a-f]{64}")
# Only these sniffed formats are written to the thumbnail cache.
IMAGE_TYPES = ((b"\x89PNG\r\n\x1a\n", "png"), (b"\xff\xd8\xff", "jpg"), (b"GIF87a", "gif"),
               (b"GIF89a", "gif"), (b"BM", "bmp"))
EXTENSIONS = ("png", "jpg", "gif", "bmp", "webp")
THUMB_BATCH = 12


def pins_dir():
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local/state")
    return Path(base) / "caelestia" / "island-clipboard-pins"


def pins():
    result = []
    for file in sorted(pins_dir().glob('p*.json'), key=lambda p: p.stat().st_mtime, reverse=True):
        if not PIN_ID.fullmatch(file.stem):
            continue
        try:
            item = json.loads(file.read_text())
            if item['id'] == file.stem and isinstance(item['label'], str) and (file.with_suffix('.bin')).is_file():
                result.append({**item, 'pinned': True})
        except (OSError, ValueError, KeyError, TypeError):
            continue
    return result


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    handle, temporary = tempfile.mkstemp(dir=path.parent, prefix='.tmp-')
    try:
        with os.fdopen(handle, 'wb') as stream:
            stream.write(data)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def decode(key):
    if PIN_ID.fullmatch(key):
        return (pins_dir() / f'{key}.bin').read_bytes()
    if not ID.fullmatch(key):
        raise RuntimeError('Invalid clipboard entry')
    return run(['cliphist', 'decode'], (key + '\t').encode())


def pin(key):
    if not ID.fullmatch(key):
        raise RuntimeError('Invalid clipboard entry')
    entry = next((item for item in entries(run(['cliphist', 'list'])) if item['id'] == key), None)
    if not entry:
        raise RuntimeError('This clipboard entry is no longer available')
    data = decode(key)
    if len(data) > 32 * 1024 * 1024:
        raise RuntimeError('Pinned items must be smaller than 32 MiB')
    saved_id = 'p' + hashlib.sha256(data).hexdigest()
    if len(pins()) >= 40 and not (pins_dir() / f'{saved_id}.json').exists():
        raise RuntimeError('Unpin an item first (40 pinned items maximum)')
    record = {**entry, 'id': saved_id, 'sourceId': key, 'pinned': True}
    atomic_write(pins_dir() / f'{saved_id}.bin', data)
    atomic_write(pins_dir() / f'{saved_id}.json', json.dumps(record, ensure_ascii=False).encode())


def unpin(key):
    if not PIN_ID.fullmatch(key):
        raise RuntimeError('Invalid pinned entry')
    for ext in ['json', 'bin']:
        (pins_dir() / f'{key}.{ext}').unlink(missing_ok=True)


def run(args, data=None):
    # wl-copy forks a selection owner. It must not retain our collector pipes.
    detached_output = args[0] == "wl-copy"
    result = subprocess.run(args, input=data,
                            stdout=subprocess.DEVNULL if detached_output else subprocess.PIPE,
                            stderr=subprocess.DEVNULL if detached_output else subprocess.PIPE,
                            start_new_session=detached_output,
                            timeout=15, check=False)
    if result.returncode:
        raise RuntimeError("Clipboard command failed")
    return result.stdout or b""


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "caelestia" / "island-clipboard"


def image_extension(data):
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    return next((ext for magic, ext in IMAGE_TYPES if data.startswith(magic)), None)


def cached(folder, key):
    return next((folder / f"{key}.{ext}" for ext in EXTENSIONS if (folder / f"{key}.{ext}").is_file()), None)


def thumbnail(folder, key):
    """Decode one entry into the cache, reusing an existing file. Returns a path or None."""
    existing = cached(folder, key)
    if existing:
        return existing
    data = decode(key)
    ext = image_extension(data)
    if not ext:
        return None
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    target = folder / f"{key}.{ext}"
    handle, temporary = tempfile.mkstemp(dir=folder, prefix=".tmp-")
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(data)
        os.replace(temporary, target)
    except OSError:
        Path(temporary).unlink(missing_ok=True)
        raise
    return target


def prune(folder, keep):
    if not folder.is_dir():
        return
    for item in folder.iterdir():
        stem, _, ext = item.name.partition(".")
        # A concurrent thumbnail write may still own a fresh temporary file.
        stale_temp = item.name.startswith(".tmp-") and time.time() - item.stat().st_mtime > 60
        if stale_temp or (ext in EXTENSIONS and (ID.fullmatch(stem) or PIN_ID.fullmatch(stem)) and stem not in keep):
            item.unlink(missing_ok=True)


def thumbnails(keys):
    folder = cache_dir()
    result = {}
    for key in keys[:THUMB_BATCH]:
        try:
            path = thumbnail(folder, key)
        except (RuntimeError, subprocess.TimeoutExpired, OSError):
            path = None
        result[key] = str(path) if path else ""
    return result


def entries(data):
    items = []
    for line in data.decode("utf-8", errors="replace").splitlines():
        key, sep, label = line.partition("\t")
        if sep and ID.fullmatch(key):
            image = "[[ binary data" in label.lower()
            kind = 'image' if image else 'link' if re.fullmatch(r'https?://\S+', label.strip(), re.I) else 'code' if re.search(r'^\s*(?:(?:const|let|var|def|class|function|import|from|#include)\s|[\[{].*[:\"]|<\w+[^>]*>)', label) else 'text'
            items.append({"id": key, "label": label, "image": image, "type": kind, "pinned": False})
        if len(items) >= 200:
            break
    return items


def main():
    if not shutil.which("cliphist") or not shutil.which("wl-copy"):
        raise RuntimeError("Install cliphist and wl-clipboard to use clipboard history")
    action = sys.argv[1]
    if action == "list":
        saved = pins()
        sources = {(item.get('sourceId'), item['label']) for item in saved}
        items = saved + [item for item in entries(run(["cliphist", "list"])) if (item['id'], item['label']) not in sources]
        prune(cache_dir(), {item["id"] for item in items})
        return {"entries": items}
    keys = sys.argv[2:] if action == "thumbs" else sys.argv[2:3]
    if not keys or not all(ID.fullmatch(key) or PIN_ID.fullmatch(key) for key in keys):
        raise RuntimeError("Invalid clipboard entry")
    if action == "thumbs":
        return {"thumbs": thumbnails(keys)}
    key = keys[0]
    if action == "copy":
        run(["wl-copy"], decode(key))
    elif action == "pin":
        pin(key)
    elif action == "unpin":
        unpin(key)
    elif action == "delete":
        if not ID.fullmatch(key):
            raise RuntimeError('Unpin this item to remove its saved copy')
        run(["cliphist", "delete"], (key + "\t").encode())
        existing = cached(cache_dir(), key)
        if existing:
            existing.unlink(missing_ok=True)
    else:
        raise RuntimeError("Unknown clipboard action")
    return {"ok": True}


if __name__ == "__main__":
    try:
        print(json.dumps(main(), ensure_ascii=False))
    except (RuntimeError, subprocess.TimeoutExpired, OSError, IndexError) as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
