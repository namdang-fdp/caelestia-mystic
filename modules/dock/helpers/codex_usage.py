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
AUTH_WORDS = ("auth", "login", "log in", "sign in", "signed in", "logged in", "unauthorized", "credential", "api key")
PLAN_NAMES = {"plus": "Plus", "pro": "Pro", "team": "Team", "business": "Business", "enterprise": "Enterprise", "edu": "Edu", "free": "Free"}


class UsageError(Exception):
    pass


class NotInstalled(UsageError):
    pass


class CodexUnavailable(UsageError):
    pass


def codex_candidates() -> list[Path]:
    home = Path.home()
    # The ChatGPT desktop app bundles its own CLI
    return [home / ".local/bin/codex", home / ".npm-global/bin/codex", home / ".bun/bin/codex",
            home / ".volta/bin/codex", home / ".local/share/pnpm/codex", Path("/usr/bin/codex"),
            Path("/usr/lib/chatgpt/resources/codex")]


def find_codex_executables() -> list[str]:
    path_match = shutil.which("codex")
    candidates = ([Path(path_match)] if path_match else []) + codex_candidates()
    return list(dict.fromkeys(str(path) for path in candidates
                              if path.is_file() and os.access(path, os.X_OK)))


def rpc_error(error) -> str:
    message = str(error.get("message") or "") if isinstance(error, dict) else ""
    lowered = message.lower()
    if any(word in lowered for word in AUTH_WORDS):
        return "Sign in to Codex to see usage"
    return f"Codex usage request failed: {message[:80]}" if message else "Codex usage request failed"


def read_response(fd: int, request_id: int, timeout: float) -> dict:
    """Read newline separated JSON-RPC messages from fd until the response to request_id arrives.

    Reads the raw fd instead of a buffered file so select() never misses lines already buffered.
    """
    selector = selectors.DefaultSelector()
    selector.register(fd, selectors.EVENT_READ)
    buffer = b""
    deadline = time.monotonic() + timeout
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise UsageError("Codex usage request timed out")
            if not selector.select(timeout=remaining):
                continue
            chunk = os.read(fd, 65536)
            if not chunk:
                raise CodexUnavailable("Codex exited before reporting usage")
            buffer += chunk
            *lines, buffer = buffer.split(b"\n")
            for line in lines:
                try:
                    message = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(message, dict) or message.get("id") != request_id:
                    continue
                if "error" in message:
                    raise UsageError(rpc_error(message["error"]))
                return message.get("result") or {}
    finally:
        selector.close()


def request_rate_limits() -> dict:
    candidates = find_codex_executables()
    if not candidates:
        raise NotInstalled("Codex CLI is not installed")

    first_error = None
    for codex in candidates:
        try:
            return request_rate_limits_from(codex)
        except CodexUnavailable as exc:
            # An executable launcher can still depend on a missing runtime.
            if first_error is None:
                first_error = exc
    raise first_error


def request_rate_limits_from(codex: str) -> dict:
    try:
        process = subprocess.Popen([codex, "app-server", "--stdio"], stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
    except OSError as exc:
        raise CodexUnavailable("Unable to start Codex") from exc

    with process:
        try:
            for message in ({"method": "initialize", "id": 1, "params": {"clientInfo": CLIENT_INFO}},
                            {"method": "initialized"},
                            {"method": "account/rateLimits/read", "id": 2}):
                process.stdin.write((json.dumps(message) + "\n").encode())

            return read_response(process.stdout.fileno(), 2, TIMEOUT_SECONDS)
        except BrokenPipeError as exc:
            raise CodexUnavailable("Codex exited before reporting usage") from exc
        finally:
            process.kill()


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
        output = {"available": False, "installed": not isinstance(exc, NotInstalled), "plan": "", "limits": [], "error": str(exc)}
    except Exception:
        output = {"available": False, "plan": "", "limits": [], "error": "Codex usage is unavailable"}
    print(json.dumps(output))


if __name__ == "__main__":
    main()
