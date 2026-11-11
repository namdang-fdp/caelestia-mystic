#!/usr/bin/env python3
"""Print the current agent sessions, one JSON object per line.

Claude Code sessions come from the files agent_hook.py writes. Codex needs no
hook: its rollout logs say whether a turn has started or completed, so recent
logs are read directly and Codex's own configuration is left alone. A hook
file for the same session, if one exists, wins over the log.
"""

from __future__ import annotations

import json
import os
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

CODEX_WORKING_FRESH = 120  # seconds without log writes before a turn is presumed dead
CODEX_DONE_VISIBLE = 180
TAIL_BYTES = 256 * 1024


def state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "caelestia" / "agents"


def hook_sessions(directory: Path) -> list[dict]:
    found = []
    for path in sorted(directory.glob("*.json")):
        try:
            data = json.loads(path.read_text())
        except (OSError, ValueError):
            continue
        if isinstance(data, dict):
            found.append(data)
    return found


def tail_lines(path: Path) -> list[str]:
    with path.open("rb") as handle:
        handle.seek(0, os.SEEK_END)
        size = handle.tell()
        handle.seek(max(0, size - TAIL_BYTES))
        data = handle.read().decode("utf-8", "replace")
    lines = data.splitlines()
    return lines[1:] if size > TAIL_BYTES else lines


def parse_time(value) -> float | None:
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def codex_session(path: Path, now: float) -> dict | None:
    try:
        mtime = path.stat().st_mtime
        lines = tail_lines(path)
    except OSError:
        return None
    state = started = None
    for line in reversed(lines):
        if '"task_started"' not in line and '"task_complete"' not in line and '"turn_aborted"' not in line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue
        kind = (row.get("payload") or {}).get("type")
        if kind in ("task_started", "task_complete", "turn_aborted"):
            state = "working" if kind == "task_started" else "done"
            started = parse_time(row.get("timestamp")) or mtime
            break
    if state is None:
        return None
    age = now - mtime
    if (state == "working" and age > CODEX_WORKING_FRESH) or (state == "done" and age > CODEX_DONE_VISIBLE):
        return None
    cwd = ""
    try:
        with path.open(errors="replace") as handle:
            meta = json.loads(handle.readline())
        cwd = str((meta.get("payload") or {}).get("cwd") or "")
        session = str((meta.get("payload") or {}).get("id") or path.stem)
    except (OSError, ValueError):
        session = path.stem
    return {"agent": "codex", "session": session, "project": Path(cwd).name if cwd else "",
            "state": state, "started": started, "updated": mtime}


def codex_sessions(root: Path, now: float) -> list[dict]:
    today = datetime.fromtimestamp(now).date()
    found = []
    for day in (today, today - timedelta(days=1)):
        folder = root / f"{day:%Y}" / f"{day:%m}" / f"{day:%d}"
        if not folder.is_dir():
            continue
        for path in folder.glob("rollout-*.jsonl"):
            try:
                if now - path.stat().st_mtime > max(CODEX_WORKING_FRESH, CODEX_DONE_VISIBLE):
                    continue
            except OSError:
                continue
            session = codex_session(path, now)
            if session:
                found.append(session)
    return found


def collect(home: Path, directory: Path, now: float) -> list[dict]:
    sessions = hook_sessions(directory) if directory.is_dir() else []
    seen = {(s.get("agent"), s.get("session")) for s in sessions}
    for session in codex_sessions(home / ".codex" / "sessions", now):
        if ("codex", session["session"]) not in seen:
            sessions.append(session)
    return sessions


if __name__ == "__main__":
    for item in collect(Path.home(), state_dir(), time.time()):
        sys.stdout.write(json.dumps(item) + "\n")
