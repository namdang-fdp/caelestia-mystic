#!/usr/bin/env python3
"""Print normalized Claude plan usage as JSON.

Reads the OAuth token written by Claude Code and queries the same endpoint
its /usage command uses. The token is never printed. When it has expired,
`claude auth status` is run so Claude Code refreshes it; this script never
writes the credentials file itself.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
TIMEOUT_SECONDS = 15
PLAN_NAMES = {"max": "Max", "pro": "Pro", "team": "Team", "enterprise": "Enterprise"}


class UsageError(Exception):
    pass


def config_dir() -> Path:
    return Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")


def read_oauth() -> dict:
    try:
        data = json.loads((config_dir() / ".credentials.json").read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise UsageError("Sign in to Claude Code to see usage") from exc
    except (OSError, ValueError) as exc:
        raise UsageError("Unable to read Claude Code credentials") from exc
    oauth = data.get("claudeAiOauth")
    if not isinstance(oauth, dict) or not oauth.get("accessToken"):
        raise UsageError("Sign in to Claude Code to see usage")
    return oauth


def find_claude() -> str | None:
    found = shutil.which("claude")
    if found:
        return found
    for candidate in (Path.home() / ".local/bin/claude", Path.home() / ".claude/local/claude", Path("/usr/bin/claude")):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def refresh_token() -> None:
    claude = find_claude()
    if claude is None:
        return
    try:
        subprocess.run([claude, "auth", "status"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=30, check=False)
    except (OSError, subprocess.SubprocessError):
        pass


def expired(oauth: dict) -> bool:
    expires_at = oauth.get("expiresAt")
    return isinstance(expires_at, (int, float)) and expires_at / 1000 < time.time() + 60


def fetch(token: str) -> dict:
    request = urllib.request.Request(USAGE_URL, headers={
        "Authorization": f"Bearer {token}",
        "anthropic-beta": "oauth-2025-04-20",
        "Content-Type": "application/json",
        "User-Agent": "caelestia-dock/1.0",
    })
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return json.load(response)


def epoch(value) -> float | None:
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value).timestamp()
    except ValueError:
        return None


def percent(value) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return max(0.0, min(100.0, float(value)))


def normalize(data: dict) -> list[dict]:
    limits = []
    raw_limits = data.get("limits")
    if isinstance(raw_limits, list):
        for raw in raw_limits:
            if not isinstance(raw, dict) or percent(raw.get("percent")) is None:
                continue
            kind = raw.get("kind")
            if kind == "session":
                limit_id, label, window = "session", "Session", 300
            elif kind == "weekly_all":
                limit_id, label, window = "weekly", "Weekly", 10080
            elif kind == "weekly_scoped":
                model = ((raw.get("scope") or {}).get("model") or {}).get("display_name")
                if not model:
                    continue
                limit_id, label, window = f"weekly-{model.lower()}", f"Weekly · {model}", 10080
            else:
                continue
            limits.append({
                "id": limit_id,
                "label": label,
                "usedPercent": percent(raw.get("percent")),
                "resetsAt": epoch(raw.get("resets_at")),
                "windowMins": window,
            })

    if not limits:
        for key, limit_id, label, window in (("five_hour", "session", "Session", 300), ("seven_day", "weekly", "Weekly", 10080)):
            raw = data.get(key)
            if isinstance(raw, dict) and percent(raw.get("utilization")) is not None:
                limits.append({
                    "id": limit_id,
                    "label": label,
                    "usedPercent": percent(raw.get("utilization")),
                    "resetsAt": epoch(raw.get("resets_at")),
                    "windowMins": window,
                })
    return limits


def collect() -> dict:
    oauth = read_oauth()
    if expired(oauth):
        refresh_token()
        oauth = read_oauth()

    try:
        data = fetch(oauth["accessToken"])
    except urllib.error.HTTPError as exc:
        if exc.code != 401:
            raise UsageError(f"Claude usage request failed ({exc.code})") from exc
        refresh_token()
        oauth = read_oauth()
        try:
            data = fetch(oauth["accessToken"])
        except urllib.error.HTTPError as retry_exc:
            if retry_exc.code == 401:
                raise UsageError("Claude Code session expired, run claude to sign in again") from retry_exc
            raise UsageError(f"Claude usage request failed ({retry_exc.code})") from retry_exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise UsageError("Unable to reach Claude") from exc
    except ValueError as exc:
        raise UsageError("Claude returned an invalid usage response") from exc

    limits = normalize(data)
    if not limits:
        raise UsageError("Claude usage is unavailable")

    plan = PLAN_NAMES.get(str(oauth.get("subscriptionType") or "").lower(), "")
    tier = str(oauth.get("rateLimitTier") or "")
    if plan == "Max" and tier.endswith("_20x"):
        plan = "Max 20x"
    elif plan == "Max" and tier.endswith("_5x"):
        plan = "Max 5x"
    return {"available": True, "plan": plan, "limits": limits, "error": None}


def main() -> None:
    try:
        result = collect()
    except UsageError as exc:
        result = {"available": False, "plan": "", "limits": [], "error": str(exc)}
    except Exception:
        result = {"available": False, "plan": "", "limits": [], "error": "Claude usage is unavailable"}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
