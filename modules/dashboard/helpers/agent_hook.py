#!/usr/bin/env python3
"""Record an AI agent's state for the island and, for Claude Code, let the
island answer permission prompts.

Called from Claude Code / Codex hooks: `agent_hook.py <agent>`; the hook
payload arrives as JSON on stdin. The state file (0600) holds the agent,
project folder, working directory, process id, state and timestamps. While a
permission request is waiting it also holds the tool name and a one-line
summary of what is being asked (for example the command), so you can see what
you are approving; that detail is dropped as soon as the state changes. The
prompt text and tool output are never stored.

Every event except PermissionRequest prints nothing and returns at once. For a
PermissionRequest the hook waits up to five minutes for the island to write a
matching decision file, then prints Claude Code's allow/deny JSON. If nobody
answers, or the prompt is answered elsewhere, it prints nothing and the normal
terminal prompt decides. The script always exits 0 so it can never block an agent.
"""

from __future__ import annotations

import json
import os
import re
import secrets
import sys
import time
from pathlib import Path

WORKING = {"UserPromptSubmit", "PreToolUse", "PostToolUse", "SubagentStart", "SubagentStop", "PreCompact",
           "BeforeAgent", "BeforeTool", "AfterTool"}
WAITING = {"PermissionRequest"}
DONE = {"Stop", "AfterAgent"}
ENDED = {"SessionEnd"}
IDLE_NOTIFICATIONS = {"idle_prompt"}
# Prompts that ask a question rather than approve an action: the island can
# take you to the window but never answers them.
NOT_DECIDABLE = {"AskUserQuestion", "ExitPlanMode"}
DETAIL_KEYS = ("command", "file_path", "url", "pattern", "path", "description", "query")
WAIT_LIMIT_SECONDS = 300


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


def summarize(tool_input) -> str:
    """One line describing what a tool wants to do, at most 160 characters."""
    if not isinstance(tool_input, dict):
        return ""
    for key in DETAIL_KEYS:
        value = tool_input.get(key)
        if isinstance(value, str) and value.strip():
            return " ".join(value.split())[:160]
    return ""


def decision_path(directory: Path, agent: str, session: str) -> Path:
    return directory / "decisions" / f"{safe(agent.lower())}-{safe(session)}.json"


def record(agent: str, payload: dict, directory: Path, now: float | None = None, pid: int | None = None) -> bool:
    event = str(payload.get("hook_event_name") or payload.get("event") or "")
    state = "end" if agent.lower() == "codex" and event == "Interrupt" else classify(event, payload)
    if state is None:
        return False
    now = time.time() if now is None else now
    session = safe(str(payload.get("session_id") or payload.get("session") or payload.get("thread_id") or "default"))
    agent = safe(agent.lower())
    path = directory / f"{agent}-{session}.json"
    if state == "end":
        path.unlink(missing_ok=True)
        decision_path(directory, agent, session).unlink(missing_ok=True)
        return True
    directory.mkdir(parents=True, exist_ok=True)
    os.chmod(directory, 0o700)
    started = now
    previous = {}
    try:
        previous = json.loads(path.read_text())
        if previous.get("state") == state:
            started = float(previous.get("started", now))
    except (OSError, ValueError, TypeError):
        previous = {}
    if agent == "codex" and event == "PostToolUse":
        # Codex logs supply regular work state. This hook only clears an approval.
        if previous.get("state") == "waiting":
            path.unlink(missing_ok=True)
            return False
        if not previous:
            return False
    if agent == "codex" and event == "Stop" and not previous:
        return False
    cwd = str(payload.get("cwd") or previous.get("cwd") or "")
    data = {
        "agent": agent,
        "session": session,
        "project": Path(cwd).name if cwd else "",
        "cwd": cwd,
        "pid": pid if pid is not None else previous.get("pid", 0),
        "state": state,
        "started": started,
        "updated": now,
    }
    if state == "waiting":
        tool = str(payload.get("tool_name") or "")
        if event == "PermissionRequest":
            data.update({
                "tool": tool[:48],
                "detail": summarize(payload.get("tool_input")),
                "request": str(payload.get("tool_use_id") or secrets.token_hex(8))[:64],
                "decidable": agent == "claude" and bool(tool) and tool not in NOT_DECIDABLE,
            })
        elif previous.get("state") == "waiting":
            # The Notification that follows a PermissionRequest must not erase its detail.
            for key in ("tool", "detail", "request", "decidable"):
                if key in previous:
                    data[key] = previous[key]
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


def current_request(directory: Path, agent: str, session: str) -> str | None:
    """The request id of the session's waiting state, or None once it moved on."""
    try:
        data = json.loads((directory / f"{safe(agent.lower())}-{safe(session)}.json").read_text())
    except (OSError, ValueError):
        return None
    return str(data.get("request")) if data.get("state") == "waiting" and data.get("request") else None


def wait_for_decision(directory: Path, agent: str, session: str, request: str,
                      limit: float = WAIT_LIMIT_SECONDS, poll: float = 0.25,
                      sleep=time.sleep, clock=time.monotonic) -> str | None:
    """Waits for the island's answer to exactly this request: "allow", "deny" or None.

    Gives up when the request is no longer the waiting one (answered in the
    terminal, or the next event arrived) or after `limit` seconds. A decision
    for a different request is ignored, so one click never approves the next prompt.
    """
    path = decision_path(directory, agent, session)
    deadline = clock() + limit
    while clock() < deadline:
        try:
            data = json.loads(path.read_text())
        except (OSError, ValueError):
            data = None
        if isinstance(data, dict) and data.get("request") == request and data.get("behavior") in ("allow", "deny"):
            path.unlink(missing_ok=True)
            return data["behavior"]
        if current_request(directory, agent, session) != request:
            return None
        sleep(poll)
    return None


def decision_output(behavior: str) -> str:
    decision = {"behavior": behavior}
    if behavior == "deny":
        decision["message"] = "Denied from the island"
    return json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": decision}})


def main() -> int:
    try:
        agent = sys.argv[1] if len(sys.argv) > 1 else "agent"
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
        if len(sys.argv) > 2 and isinstance(payload, dict):
            payload.setdefault("hook_event_name", sys.argv[2])
        if isinstance(payload, dict) and record(agent, payload, state_dir(), pid=os.getppid()):
            directory = state_dir()
            session = safe(str(payload.get("session_id") or payload.get("session") or payload.get("thread_id") or "default"))
            request = current_request(directory, agent, session)
            event = str(payload.get("hook_event_name") or payload.get("event") or "")
            if event == "PermissionRequest" and agent.lower() == "claude" and request:
                try:
                    waiting = json.loads((directory / f"{safe(agent.lower())}-{session}.json").read_text())
                except (OSError, ValueError):
                    waiting = {}
                if waiting.get("decidable"):
                    behavior = wait_for_decision(directory, agent, session, request)
                    if behavior:
                        sys.stdout.write(decision_output(behavior))
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
