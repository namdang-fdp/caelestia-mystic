#!/usr/bin/env python3
"""Print token and call statistics for local Claude Code and Codex logs as JSON.

Everything comes from log files already on this machine. The 5-hour session
is an estimate: it starts at the first request after the previous window
ended, and is not the provider's official quota.
"""

from __future__ import annotations

import json
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

WINDOW = 5 * 3600
DAYS = 7


def parse_time(value) -> float | None:
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def recent_files(root: Path, since: float):
    if not root.is_dir():
        return
    for path in root.rglob("*.jsonl"):
        try:
            if path.stat().st_mtime >= since:
                yield path
        except OSError:
            continue


def claude_events(root: Path, since: float):
    """(timestamp, tokens) for each distinct assistant response."""
    seen: set[str] = set()
    for path in recent_files(root, since):
        try:
            with path.open(errors="replace") as handle:
                for line in handle:
                    if '"usage"' not in line or '"assistant"' not in line:
                        continue
                    try:
                        row = json.loads(line)
                    except ValueError:
                        continue
                    message = row.get("message")
                    if row.get("type") != "assistant" or not isinstance(message, dict):
                        continue
                    usage = message.get("usage")
                    stamp = parse_time(row.get("timestamp"))
                    if not isinstance(usage, dict) or stamp is None or stamp < since:
                        continue
                    key = f"{message.get('id')}:{row.get('requestId')}"
                    if message.get("id") and key in seen:
                        continue
                    seen.add(key)
                    tokens = sum(int(usage.get(k) or 0) for k in ("input_tokens", "output_tokens", "cache_creation_input_tokens"))
                    yield stamp, tokens
        except OSError:
            continue


def codex_events(root: Path, since: float):
    for path in recent_files(root, since):
        try:
            with path.open(errors="replace") as handle:
                for line in handle:
                    if '"token_count"' not in line:
                        continue
                    try:
                        row = json.loads(line)
                    except ValueError:
                        continue
                    payload = row.get("payload")
                    info = payload.get("info") if isinstance(payload, dict) else None
                    last = info.get("last_token_usage") if isinstance(info, dict) else None
                    stamp = parse_time(row.get("timestamp"))
                    if not isinstance(last, dict) or stamp is None or stamp < since:
                        continue
                    yield stamp, int(last.get("input_tokens") or 0) - int(last.get("cached_input_tokens") or 0) + int(last.get("output_tokens") or 0)
        except OSError:
            continue


def summarize(events, now: float) -> dict:
    events = sorted(events)
    today = datetime.fromtimestamp(now).date()
    days = {today - timedelta(days=i): [0, 0] for i in range(DAYS - 1, -1, -1)}
    start = None
    window = [0, 0]
    for stamp, tokens in events:
        day = datetime.fromtimestamp(stamp).date()
        if day in days:
            days[day][0] += tokens
            days[day][1] += 1
        if start is None or stamp >= start + WINDOW:
            start, window = stamp, [0, 0]
        window[0] += tokens
        window[1] += 1
    active = start is not None and now < start + WINDOW
    return {
        "available": bool(events),
        "fiveHour": {"active": active, "start": start if active else 0, "resetsAt": start + WINDOW if active else 0, "tokens": window[0] if active else 0, "calls": window[1] if active else 0},
        "today": {"tokens": days[today][0], "calls": days[today][1]},
        "week": [{"date": d.isoformat(), "tokens": v[0], "calls": v[1]} for d, v in days.items()],
    }


def collect(home: Path, now: float) -> dict:
    since = datetime.combine(datetime.fromtimestamp(now).date() - timedelta(days=DAYS - 1), datetime.min.time()).timestamp()
    return {
        "updated": now,
        "providers": {
            "claude": summarize(claude_events(home / ".claude" / "projects", since - WINDOW), now),
            "codex": summarize(codex_events(home / ".codex" / "sessions", since - WINDOW), now),
        },
    }


if __name__ == "__main__":
    json.dump(collect(Path.home(), time.time()), sys.stdout)
