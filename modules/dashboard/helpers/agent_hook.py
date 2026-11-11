#!/usr/bin/env python3
"""Record an AI agent's state for the island.

Called from Claude Code / Codex hooks: `agent_hook.py <agent>`; the hook
payload arrives as JSON on stdin. Only the agent, project folder name, state
and timestamps are stored: never the prompt, command or output. This script
always exits 0 so it can never block an agent.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path

WORKING = {"UserPromptSubmit", "PreToolUse", "PostToolUse", "SubagentStart", "SubagentStop", "PreCompact",
           "BeforeAgent", "BeforeTool", "AfterTool"}
WAITING = {"PermissionRequest"}
DONE = {"Stop", "AfterAgent"}
ENDED = {"SessionEnd"}
IDLE_NOTIFICATIONS = {"idle_prompt"}


def state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "caelestia" / "agents"


def classify(event: str, payload: dict) -> str | None:
    """Returns working / waiting / done, "end" to forget the session, or None to ignore."""
    if event in ENDED:
        return "end"
    if event in WAITING:
        return "waiting"
    if event == "Notification":
        kind = str(payload.get("notification_type") or "")
        message = str(payload.get("message") or "").lower()
        if kind in IDLE_NOTIFICATIONS:
            return "done"
        if kind == "permission_prompt" or "permission" in message or "approv" in message:
            return "waiting"
        return None
    if event in DONE:
        return "done"
    if event in WORKING:
        return "working"
    return None


def safe(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", value)[:96] or "unknown"


def record(agent: str, payload: dict, directory: Path, now: float | None = None) -> bool:
    event = str(payload.get("hook_event_name") or payload.get("event") or "")
    state = classify(event, payload)
    if state is None:
        return False
    now = time.time() if now is None else now
    session = safe(str(payload.get("session_id") or payload.get("session") or payload.get("thread_id") or "default"))
    agent = safe(agent.lower())
    path = directory / f"{agent}-{session}.json"
    if state == "end":
        path.unlink(missing_ok=True)
        return True
    directory.mkdir(parents=True, exist_ok=True)
    os.chmod(directory, 0o700)
    started = now
    try:
        previous = json.loads(path.read_text())
        if previous.get("state") == state:
            started = float(previous.get("started", now))
    except (OSError, ValueError, TypeError):
        pass
    cwd = str(payload.get("cwd") or "")
    data = {
        "agent": agent,
        "session": session,
        "project": Path(cwd).name if cwd else "",
        "state": state,
        "started": started,
        "updated": now,
    }
    temporary = path.with_suffix(".tmp")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as handle:
        json.dump(data, handle)
    os.replace(temporary, path)
    prune(directory, now)
    return True


def prune(directory: Path, now: float) -> None:
    """Remove files of sessions that stopped reporting more than a day ago."""
    for item in directory.glob("*.json"):
        try:
            if now - item.stat().st_mtime > 86400:
                item.unlink()
        except OSError:
            pass


def main() -> int:
    try:
        agent = sys.argv[1] if len(sys.argv) > 1 else "agent"
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
        if len(sys.argv) > 2 and isinstance(payload, dict):
            payload.setdefault("hook_event_name", sys.argv[2])
        if isinstance(payload, dict):
            record(agent, payload, state_dir())
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
