#!/usr/bin/env python3
"""Add or remove the island's zsh hook in ~/.zshrc.

    shell_setup.py status | install | uninstall

The hook is one marked block that sources shell-hook.zsh from this repository.
Everything outside the block is left untouched, and a timestamped backup is
written before every change.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

BEGIN = "# >>> caelestia island commands >>>"
END = "# <<< caelestia island commands <<<"
HOOK = Path(__file__).with_name("shell-hook.zsh")


def zshrc() -> Path:
    return Path(os.environ.get("ZSHRC") or Path.home() / ".zshrc")


def block() -> str:
    return f"{BEGIN}\n[[ -r {HOOK} ]] && source {HOOK}\n{END}\n"


def split(text: str):
    """(before, found, after) around the marked block."""
    start = text.find(BEGIN)
    if start < 0:
        return text, False, ""
    end = text.find(END, start)
    if end < 0:
        return text, False, ""
    end += len(END)
    if text[end:end + 1] == "\n":
        end += 1
    return text[:start], True, text[end:]


def status(path: Path) -> dict:
    try:
        return {"installed": split(path.read_text())[1]}
    except FileNotFoundError:
        return {"installed": False}


def write(path: Path, text: str) -> None:
    if path.exists():
        shutil.copy2(path, path.with_name(f"{path.name}.bak-island-{time.strftime('%Y%m%d-%H%M%S')}"))
    handle, temporary = tempfile.mkstemp(dir=path.parent, prefix=".tmp-zshrc-")
    try:
        with os.fdopen(handle, "w") as stream:
            stream.write(text)
        if path.exists():
            os.chmod(temporary, path.stat().st_mode & 0o777)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def install(path: Path) -> None:
    text = path.read_text() if path.exists() else ""
    before, found, after = split(text)
    if found:
        text = before + block() + after
    else:
        text = text + ("" if text.endswith("\n") or not text else "\n") + "\n" + block()
    write(path, text)


def uninstall(path: Path) -> None:
    if not path.exists():
        return
    before, found, after = split(path.read_text())
    if found:
        write(path, before.rstrip("\n") + ("\n" if before.strip() else "") + after.lstrip("\n") if after.strip() else before.rstrip("\n") + "\n")


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    path = zshrc()
    try:
        if action == "install":
            install(path)
        elif action == "uninstall":
            uninstall(path)
        elif action != "status":
            raise ValueError("usage: status | install | uninstall")
        print(json.dumps(status(path)))
        return 0
    except Exception as error:
        print(json.dumps({"installed": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
