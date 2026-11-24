#!/usr/bin/env python3
"""Actions the island takes on an agent session.

    agent_action.py decide <agent> <session> <request> allow|deny
    agent_action.py focus <agent> <pid> <cwd> [session]

`decide` writes the decision file that agent_hook.py is waiting for; it is
only ever read for that exact request. `focus` raises the terminal window the
session runs in: it walks up from the agent's process to the first process that
owns a Hyprland window.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from agent_hook import decision_path, safe, state_dir  # noqa: E402

ADDRESS = re.compile(r"0x[0-9a-fA-F]+")
THREAD_ID = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", re.IGNORECASE)
MAX_DEPTH = 40


def write_decision(directory: Path, agent: str, session: str, request: str, behavior: str) -> Path:
    if behavior not in ("allow", "deny") or not request:
        raise ValueError("A decision needs a request and allow or deny")
    path = decision_path(directory, agent, session)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    handle, temporary = tempfile.mkstemp(dir=path.parent, prefix=".tmp-")
    try:
        with os.fdopen(handle, "w") as stream:
            json.dump({"request": request, "behavior": behavior}, stream)
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return path


def parent_pid(pid: int, proc: Path = Path("/proc")) -> int:
    try:
        stat = (proc / str(pid) / "stat").read_text()
        return int(stat[stat.rindex(")") + 2:].split()[1])
    except (OSError, ValueError, IndexError):
        return 0


def ancestors(pid: int, proc: Path = Path("/proc")):
    seen = set()
    for _ in range(MAX_DEPTH):
        if pid <= 1 or pid in seen:
            return
        seen.add(pid)
        yield pid
        pid = parent_pid(pid, proc)


def find_agent_pid(agent: str, cwd: str, proc: Path = Path("/proc")) -> int:
    """Find a terminal agent only when its project identifies a single process."""
    if not cwd or agent not in ("claude", "codex"):
        return 0
    match = 0
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            args = (entry / "cmdline").read_bytes().split(b"\0")
            if os.path.basename(args[0].decode("utf8", "ignore")) != agent or b"app-server" in args:
                continue
            if os.readlink(entry / "cwd") == cwd:
                if match:
                    return 0
                match = int(entry.name)
        except (OSError, IndexError):
            continue
    return match


def client_for(pid: int, clients: list, proc: Path = Path("/proc")):
    by_pid = {}
    for client in clients:
        by_pid.setdefault(client.get("pid"), client)
    for candidate in ancestors(pid, proc):
        if candidate in by_pid:
            return by_pid[candidate]
    return None


def focus(agent: str, pid: int, cwd: str, run=subprocess.run, proc: Path = Path("/proc"), session="") -> dict:
    if pid <= 0 or not (proc / str(pid)).exists():
        pid = find_agent_pid(agent, cwd, proc)
    if pid > 0:
        out = run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=5).stdout
        client = client_for(pid, json.loads(out or "[]"), proc)
        if client and ADDRESS.fullmatch(str(client.get("address", ""))):
            result = run(["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{client["address"]}" }})'],
                         capture_output=True, text=True, timeout=5)
            if getattr(result, "returncode", 0) == 0:
                return {"ok": True}
    if agent == "codex" and THREAD_ID.fullmatch(session):
        opener = run(["xdg-mime", "query", "default", "x-scheme-handler/codex"], capture_output=True, text=True, timeout=5)
        if opener.stdout.strip():
            result = run(["gio", "open", f"codex://threads/{session}"], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                return {"ok": True}
    return {"error": "Could not find the session's window" if pid <= 0 else "The session has no window"}


def main(argv: list) -> dict:
    action = argv[1] if len(argv) > 1 else ""
    if action == "decide" and len(argv) == 6:
        write_decision(state_dir(), argv[2], argv[3], argv[4], argv[5])
        return {"ok": True}
    if action == "focus" and len(argv) in (5, 6):
        return focus(argv[2], int(argv[3] or 0), argv[4], session=argv[5] if len(argv) == 6 else "")
    raise ValueError("usage: decide <agent> <session> <request> allow|deny | focus <agent> <pid> <cwd> [session]")


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv)))
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
