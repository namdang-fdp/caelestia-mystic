#!/usr/bin/env python3
"""Print normalized Codex plan usage as JSON via `codex app-server`."""

from __future__ import annotations

import json
import os
import selectors
import shutil
import subprocess
import time
from pathlib import Path

TIMEOUT_SECONDS = 20
CLIENT_INFO = {"name": "caelestia_dock", "title": "Caelestia Dock", "version": "1.0.0"}
PLAN_NAMES = {"plus": "Plus", "pro": "Pro", "team": "Team", "business": "Business", "enterprise": "Enterprise", "edu": "Edu", "free": "Free"}


class UsageError(Exception):
    pass


def find_codex() -> str | None:
    found = shutil.which("codex")
    if found:
        return found
    home = Path.home()
    for candidate in (home / ".local/bin/codex", home / ".npm-global/bin/codex", home / ".bun/bin/codex",
                      home / ".volta/bin/codex", home / ".local/share/pnpm/codex", Path("/usr/bin/codex")):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def request_rate_limits() -> dict:
    codex = find_codex()
    if codex is None:
        raise UsageError("Codex CLI is not installed")

    try:
        process = subprocess.Popen([codex, "app-server", "--stdio"], stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError as exc:
        raise UsageError("Unable to start Codex") from exc

    try:
        for message in ({"method": "initialize", "id": 1, "params": {"clientInfo": CLIENT_INFO}},
                        {"method": "initialized"},
                        {"method": "account/rateLimits/read", "id": 2}):
            process.stdin.write((json.dumps(message) + "\n").encode())
        process.stdin.flush()

        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + TIMEOUT_SECONDS
        while time.monotonic() < deadline:
            if not selector.select(timeout=max(0.0, deadline - time.monotonic())):
                continue
            line = process.stdout.readline()
            if not line:
                raise UsageError("Codex exited before reporting usage")
            try:
                message = json.loads(line)
            except ValueError:
                continue
            if message.get("id") != 2:
                continue
            if "error" in message:
                raise UsageError("Sign in to Codex to see usage")
            return message.get("result") or {}
        raise UsageError("Codex usage request timed out")
    finally:
        process.kill()
        process.wait()


def percent(value) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return max(0.0, min(100.0, float(value)))


def window_label(minutes) -> tuple[str, str]:
    if minutes == 300:
        return "session", "Session"
    if minutes == 10080:
        return "weekly", "Weekly"
    if isinstance(minutes, (int, float)) and minutes > 0:
        hours = minutes / 60
        return f"window-{int(minutes)}", f"{hours:g}h window" if hours < 48 else f"{hours / 24:g}d window"
    return "window", "Window"


def collect() -> dict:
    result = request_rate_limits()
    rate_limits = result.get("rateLimits") or {}
    limits = []
    for key in ("primary", "secondary"):
        raw = rate_limits.get(key)
        if not isinstance(raw, dict) or percent(raw.get("usedPercent")) is None:
            continue
        limit_id, label = window_label(raw.get("windowDurationMins"))
        resets_at = raw.get("resetsAt")
        limits.append({
            "id": limit_id,
            "label": label,
            "usedPercent": percent(raw.get("usedPercent")),
            "resetsAt": resets_at if isinstance(resets_at, (int, float)) else None,
            "windowMins": raw.get("windowDurationMins"),
        })
    if not limits:
        raise UsageError("Codex usage is unavailable")

    plan = PLAN_NAMES.get(str(rate_limits.get("planType") or "").lower(), "")
    return {"available": True, "plan": plan, "limits": limits, "error": None}


def main() -> None:
    try:
        output = collect()
    except UsageError as exc:
        output = {"available": False, "plan": "", "limits": [], "error": str(exc)}
    except Exception:
        output = {"available": False, "plan": "", "limits": [], "error": "Codex usage is unavailable"}
    print(json.dumps(output))


if __name__ == "__main__":
    main()
