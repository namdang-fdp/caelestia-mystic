#!/usr/bin/env python3
"""Small argument-only bridge to the user's existing cliphist database."""
import json
import re
import shutil
import subprocess
import sys


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


def entries(data):
    items = []
    for line in data.decode("utf-8", errors="replace").splitlines():
        key, sep, label = line.partition("\t")
        if sep and re.fullmatch(r"[0-9]+", key):
            items.append({"id": key, "label": label,
                          "image": "[[ binary data" in label.lower()})
        if len(items) >= 200:
            break
    return items


def main():
    if not shutil.which("cliphist") or not shutil.which("wl-copy"):
        raise RuntimeError("Install cliphist and wl-clipboard to use clipboard history")
    action = sys.argv[1]
    if action == "list":
        return {"entries": entries(run(["cliphist", "list"]))}
    key = sys.argv[2]
    if not re.fullmatch(r"[0-9]+", key):
        raise RuntimeError("Invalid clipboard entry")
    if action == "copy":
        run(["wl-copy"], run(["cliphist", "decode"], (key + "\t").encode()))
    elif action == "delete":
        run(["cliphist", "delete"], (key + "\t").encode())
    else:
        raise RuntimeError("Unknown clipboard action")
    return {"ok": True}


if __name__ == "__main__":
    try:
        print(json.dumps(main(), ensure_ascii=False))
    except (RuntimeError, subprocess.TimeoutExpired, OSError, IndexError) as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
