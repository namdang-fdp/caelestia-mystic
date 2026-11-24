#!/usr/bin/env python3
"""Listening TCP ports of your own processes, plus Docker containers if available.

    dev_ports.py list
    dev_ports.py kill <pid>        SIGTERM, only for your own process that listens on a port
    dev_ports.py stop <container>  docker stop, only for a container that is running

`ss` reveals the owning process only for your own sockets, which is exactly the
set that can be stopped from here.
"""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
from pathlib import Path

USERS = re.compile(r'\("([^"]+)",pid=(\d+)')
# Agents and the shell itself open local sockets that are never a dev server.
IGNORED = {"claude", "codex", "quickshell", "qs", "Hyprland", "kitty", "claude-desktop", "chrome", "zen", "firefox"}
CONTAINER = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,100}")


def parse_ss(text: str) -> list[dict]:
    found: dict[int, dict] = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 5 or parts[0] != "LISTEN":
            continue
        address, _, port = parts[3].rpartition(":")
        if not port.isdigit():
            continue
        owner = USERS.search(line)
        entry = found.setdefault(int(port), {"port": int(port), "scope": "local", "name": "", "pid": 0})
        if not address.startswith(("127.", "[::1]", "::1")):
            entry["scope"] = "all"
        if owner and not entry["pid"]:
            entry["name"], entry["pid"] = owner.group(1), int(owner.group(2))
    return sorted(found.values(), key=lambda e: e["port"])


def describe(pid: int, proc: Path = Path("/proc")) -> dict:
    """A short command line and the project folder the process runs in."""
    try:
        args = [a for a in (proc / str(pid) / "cmdline").read_bytes().decode("utf8", "ignore").split("\0") if a]
        cmd = " ".join(os.path.basename(args[0]) if i == 0 else a for i, a in enumerate(args[:4]))[:80]
    except OSError:
        cmd = ""
    try:
        cwd = os.readlink(proc / str(pid) / "cwd")
    except OSError:
        cwd = ""
    home = str(Path.home())
    project = "" if not cwd or cwd in ("/", home) else Path(cwd).name
    return {"cmd": cmd, "project": project}


def containers(run=subprocess.run) -> list[dict]:
    try:
        out = run(["docker", "ps", "--format", "{{json .}}"], capture_output=True, text=True, timeout=4)
        if out.returncode:
            return []
        rows = [json.loads(l) for l in out.stdout.splitlines() if l.strip()]
    except (OSError, ValueError, subprocess.SubprocessError):
        return []
    return [{"name": r.get("Names", ""), "image": r.get("Image", ""), "ports": r.get("Ports", ""), "status": r.get("Status", "")} for r in rows]


def listing(run=subprocess.run) -> dict:
    out = run(["ss", "-ltnpH"], capture_output=True, text=True, timeout=5).stdout
    ports = [p for p in parse_ss(out) if p["pid"] and p["name"] not in IGNORED]
    for entry in ports:
        entry.update(describe(entry["pid"]) if entry["pid"] else {"cmd": "", "project": ""})
    return {"ports": ports, "containers": containers(run)}


def owned_by_me(pid: int, proc: Path = Path("/proc")) -> bool:
    try:
        for line in (proc / str(pid) / "status").read_text().splitlines():
            if line.startswith("Uid:"):
                return int(line.split()[1]) == os.getuid()
    except (OSError, ValueError, IndexError):
        pass
    return False


def kill(pid: int, run=subprocess.run, sender=os.kill, proc: Path = Path("/proc")) -> dict:
    listening = {p["pid"] for p in parse_ss(run(["ss", "-ltnpH"], capture_output=True, text=True, timeout=5).stdout)}
    if pid <= 1 or pid not in listening or not owned_by_me(pid, proc):
        return {"error": "That process is not yours or no longer listens"}
    sender(pid, signal.SIGTERM)
    return {"ok": True}


def stop(name: str, run=subprocess.run) -> dict:
    if not CONTAINER.fullmatch(name) or name not in {c["name"] for c in containers(run)}:
        return {"error": "That container is not running"}
    result = run(["docker", "stop", name], capture_output=True, text=True, timeout=30)
    return {"ok": True} if result.returncode == 0 else {"error": "docker stop failed"}


def main(argv: list) -> dict:
    action = argv[1] if len(argv) > 1 else ""
    if action == "list":
        return listing()
    if action == "kill" and len(argv) == 3 and argv[2].isdigit():
        return kill(int(argv[2]))
    if action == "stop" and len(argv) == 3:
        return stop(argv[2])
    raise ValueError("usage: list | kill <pid> | stop <container>")


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv)))
    except Exception as error:
        print(json.dumps({"error": str(error)[:120]}))
        sys.exit(1)
