#!/usr/bin/env python3
"""File shelf tools: zip, convert, resize and PDF.

    shelf_tools.py zip <path>...
    shelf_tools.py convert <png|jpg|webp> <path>...
    shelf_tools.py resize <longest-edge> <path>...
    shelf_tools.py pdf <path>...

Prints JSON {"outputs": [...], "skipped": n} or {"error": "..."}. Originals
are never modified or overwritten; results get a new name next to the
original (zip and pdf go to ~/Downloads).
"""
import json
import os
import sys
import time
import zipfile
from pathlib import Path

IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".tif", ".tiff", ".heic", ".avif"}
FORMATS = {"png": ("PNG", ".png"), "jpg": ("JPEG", ".jpg"), "webp": ("WEBP", ".webp")}
MAX_EDGE = 16000


def downloads():
    return Path(os.environ.get("XDG_DOWNLOAD_DIR") or Path.home() / "Downloads")


def valid_paths(values):
    """Existing regular files and directories given as absolute paths."""
    found = []
    for value in values:
        path = Path(value)
        if path.is_absolute() and path.exists():
            found.append(path)
    return found


def free_name(directory, stem, suffix):
    """A path that does not exist yet: 'a.png', 'a (1).png', ..."""
    candidate = directory / f"{stem}{suffix}"
    n = 1
    while candidate.exists():
        candidate = directory / f"{stem} ({n}){suffix}"
        n += 1
    return candidate


def stamp():
    return time.strftime("%Y%m%d-%H%M%S")


def make_zip(paths, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    target = free_name(out_dir, f"Shelf-{stamp()}", ".zip")
    used = set()
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in paths:
            roots = [path] if path.is_file() else [p for p in path.rglob("*") if p.is_file() and not p.is_symlink()]
            for file in roots:
                base = path.parent
                name = str(file.relative_to(base))
                n = 1
                while name in used:
                    name = f"{n}-{file.relative_to(base)}"
                    n += 1
                used.add(name)
                archive.write(file, name)
    return [target]


def open_image(path):
    from PIL import Image
    image = Image.open(path)
    image.load()
    return image


def flatten(image, fmt):
    """JPEG has no transparency: composite onto white. Other formats keep it."""
    from PIL import Image
    if fmt == "JPEG" and image.mode in ("RGBA", "LA", "P"):
        image = image.convert("RGBA")
        background = Image.new("RGB", image.size, "white")
        background.paste(image, mask=image.split()[-1])
        return background
    return image.convert("RGB") if fmt == "JPEG" and image.mode != "RGB" else image


def convert(paths, fmt):
    pil_format, suffix = FORMATS[fmt]
    outputs, skipped = [], 0
    for path in paths:
        if not path.is_file() or path.suffix.lower() not in IMAGE_SUFFIXES:
            skipped += 1
            continue
        try:
            image = flatten(open_image(path), pil_format)
            target = free_name(path.parent, path.stem, suffix)
            image.save(target, pil_format, **({"quality": 92} if pil_format != "PNG" else {}))
            outputs.append(target)
        except Exception:
            skipped += 1
    return outputs, skipped


def resize(paths, edge):
    edge = max(16, min(int(edge), MAX_EDGE))
    outputs, skipped = [], 0
    for path in paths:
        if not path.is_file() or path.suffix.lower() not in IMAGE_SUFFIXES:
            skipped += 1
            continue
        try:
            image = open_image(path)
            image.thumbnail((edge, edge))
            target = free_name(path.parent, f"{path.stem}-{edge}", path.suffix)
            image.save(target)
            outputs.append(target)
        except Exception:
            skipped += 1
    return outputs, skipped


def make_pdf(paths, out_dir):
    pages, skipped = [], 0
    for path in paths:
        if not path.is_file() or path.suffix.lower() not in IMAGE_SUFFIXES:
            skipped += 1
            continue
        try:
            pages.append(flatten(open_image(path), "JPEG"))
        except Exception:
            skipped += 1
    if not pages:
        raise RuntimeError("No images to put in a PDF")
    out_dir.mkdir(parents=True, exist_ok=True)
    target = free_name(out_dir, f"Shelf-{stamp()}", ".pdf")
    pages[0].save(target, "PDF", save_all=True, append_images=pages[1:], resolution=150)
    return [target], skipped


def main(argv):
    action = argv[1] if len(argv) > 1 else ""
    if action == "zip":
        paths = valid_paths(argv[2:])
        if not paths:
            raise RuntimeError("Nothing to zip")
        return {"outputs": [str(p) for p in make_zip(paths, downloads())], "skipped": len(argv[2:]) - len(paths)}
    if action == "convert":
        if len(argv) < 4 or argv[2] not in FORMATS:
            raise RuntimeError("Choose png, jpg or webp")
        outputs, skipped = convert(valid_paths(argv[3:]), argv[2])
    elif action == "resize":
        if len(argv) < 4 or not argv[2].isdigit():
            raise RuntimeError("Give a size in pixels")
        outputs, skipped = resize(valid_paths(argv[3:]), argv[2])
    elif action == "pdf":
        outputs, skipped = make_pdf(valid_paths(argv[2:]), downloads())
    else:
        raise RuntimeError("Unknown shelf tool")
    if not outputs:
        raise RuntimeError("No supported images in the selection")
    return {"outputs": [str(p) for p in outputs], "skipped": skipped}


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv)))
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
