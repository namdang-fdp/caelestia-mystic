#!/usr/bin/env python3
"""Read Codex ChatGPT rate limits through the structured App Server protocol."""

from __future__ import annotations

import json
import math
import os
import selectors
import subprocess
import sys
import time
from datetime import datetime, timezone
from typing import Any


CLIENT_INFO = {
    "name": "caelestia_ai_usage",
    "title": "Caelestia AI Usage",
    "version": "1.0.0",
}
RPC_TIMEOUT_SECONDS = 20
MAX_MESSAGE_BYTES = 8 * 1024 * 1024


class CollectorError(Exception):
    """An error safe to surface without including raw server data."""


class AppServerClient:
    def __init__(self) -> None:
        try:
            self.process = subprocess.Popen(
                ["codex", "app-server", "--stdio"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                bufsize=0,
            )
        except FileNotFoundError as exc:
            raise CollectorError("Codex CLI is not installed") from exc
        self.buffer = bytearray()

    def send(self, message: dict[str, Any]) -> None:
        if self.process.stdin is None:
            raise CollectorError("Codex App Server input is unavailable")
        try:
            payload = json.dumps(message, separators=(",", ":")).encode() + b"\n"
            self.process.stdin.write(payload)
            self.process.stdin.flush()
        except (BrokenPipeError, OSError) as exc:
            raise CollectorError("Codex App Server stopped unexpectedly") from exc

    def receive(self, request_id: int) -> dict[str, Any]:
        if self.process.stdout is None:
            raise CollectorError("Codex App Server output is unavailable")

        selector = selectors.DefaultSelector()
        selector.register(self.process.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + RPC_TIMEOUT_SECONDS
        try:
            while time.monotonic() < deadline:
                while b"\n" in self.buffer:
                    raw, _, remainder = self.buffer.partition(b"\n")
                    self.buffer = bytearray(remainder)
                    if not raw:
                        continue
                    try:
                        message = json.loads(raw)
                    except (json.JSONDecodeError, UnicodeDecodeError):
                        continue
                    if isinstance(message, dict) and message.get("id") == request_id:
                        return message

                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                if not selector.select(remaining):
                    break
                chunk = os.read(self.process.stdout.fileno(), 65536)
                if not chunk:
                    break
                self.buffer.extend(chunk)
                if len(self.buffer) > MAX_MESSAGE_BYTES:
                    raise CollectorError("Codex App Server response was too large")
        finally:
            selector.close()
        raise CollectorError("Codex quota request timed out")

    def close(self) -> None:
        if self.process.poll() is not None:
            return
        try:
            if self.process.stdin is not None:
                self.process.stdin.close()
            self.process.terminate()
            self.process.wait(timeout=2)
        except (OSError, subprocess.TimeoutExpired):
            self.process.kill()
            self.process.wait(timeout=2)


def rpc_result(message: dict[str, Any], operation: str) -> dict[str, Any]:
    if "error" in message:
        error = message.get("error")
        code = error.get("code") if isinstance(error, dict) else None
        suffix = f" ({code})" if isinstance(code, int) else ""
        raise CollectorError(f"Codex {operation} failed{suffix}")
    result = message.get("result")
    if not isinstance(result, dict):
        raise CollectorError(f"Codex {operation} returned no data")
    return result


def finite_number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) else None


def duration_label(minutes: Any) -> str:
    duration = finite_number(minutes)
    if duration is None or duration <= 0:
        return "Quota window"
    rounded = int(round(duration))
    if rounded == 300:
        return "5h"
    if rounded == 10080:
        return "Weekly"
    if rounded % 10080 == 0:
        weeks = rounded // 10080
        return f"{weeks}w"
    if rounded % 1440 == 0:
        days = rounded // 1440
        return f"{days}d"
    if rounded % 60 == 0:
        hours = rounded // 60
        return f"{hours}h"
    return f"{rounded}m"


def display_label(group: dict[str, Any], window_minutes: Any) -> str:
    window = duration_label(window_minutes)
    limit_id = str(group.get("limitId") or "")
    limit_name = group.get("limitName")
    if not isinstance(limit_name, str) or not limit_name.strip():
        return window
    name = limit_name.strip().replace("_", " ")
    if name.casefold() == limit_id.casefold() or name.casefold() == "codex":
        return window
    return f"{name} · {window}"


def normalized_window(
    group_key: str, group: dict[str, Any], slot: str, window: dict[str, Any]
) -> dict[str, Any] | None:
    used = finite_number(window.get("usedPercent"))
    if used is None:
        return None
    duration = finite_number(window.get("windowDurationMins"))
    reset = finite_number(window.get("resetsAt"))
    limit_id = str(group.get("limitId") or group_key or "codex")
    return {
        "id": f"{limit_id}-{slot}",
        "limitId": limit_id,
        "label": display_label(group, duration),
        "slot": slot,
        "windowDurationMins": int(round(duration)) if duration is not None else None,
        "remainingPercent": round(max(0.0, min(100.0, 100.0 - used)), 2),
        "resetAt": int(reset) if reset is not None and reset > 0 else None,
    }


def collect() -> dict[str, Any]:
    client = AppServerClient()
    try:
        client.send({"method": "initialize", "id": 1, "params": {"clientInfo": CLIENT_INFO}})
        rpc_result(client.receive(1), "initialization")
        client.send({"method": "initialized", "params": {}})

        # account/read is used only for the plan tier. Email and all other
        # account fields are deliberately ignored and never leave this process.
        client.send(
            {"method": "account/read", "id": 2, "params": {"refreshToken": False}}
        )
        client.send({"method": "account/rateLimits/read", "id": 3})
        account_result = rpc_result(client.receive(2), "account read")
        limit_result = rpc_result(client.receive(3), "rate-limit read")
    finally:
        client.close()

    account = account_result.get("account")
    account = account if isinstance(account, dict) else {}
    plan = account.get("planType") if isinstance(account.get("planType"), str) else None

    groups = limit_result.get("rateLimitsByLimitId")
    if not isinstance(groups, dict) or not groups:
        legacy = limit_result.get("rateLimits")
        groups = {"codex": legacy} if isinstance(legacy, dict) else {}

    quotas: list[dict[str, Any]] = []
    seen: set[tuple[Any, ...]] = set()
    for group_key, raw_group in groups.items():
        if not isinstance(raw_group, dict):
            continue
        if plan is None and isinstance(raw_group.get("planType"), str):
            plan = raw_group["planType"]
        for slot in ("primary", "secondary"):
            raw_window = raw_group.get(slot)
            if not isinstance(raw_window, dict):
                continue
            quota = normalized_window(str(group_key), raw_group, slot, raw_window)
            if quota is None:
                continue
            identity = (
                quota["limitId"],
                quota["slot"],
                quota["windowDurationMins"],
                quota["resetAt"],
            )
            if identity in seen:
                continue
            seen.add(identity)
            quotas.append(quota)

    quotas.sort(
        key=lambda quota: (
            quota["windowDurationMins"] is None,
            quota["windowDurationMins"] or 0,
            quota["label"],
        )
    )
    reset_credits = limit_result.get("rateLimitResetCredits")
    reset_count = (
        reset_credits.get("availableCount") if isinstance(reset_credits, dict) else None
    )
    reset_count_number = finite_number(reset_count)

    return {
        "available": bool(quotas),
        "loading": False,
        "stale": False,
        "updatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "plan": plan,
        "quotas": quotas,
        "resetCreditsAvailable": (
            max(0, int(reset_count_number)) if reset_count_number is not None else None
        ),
        "error": None if quotas else "Codex returned no rate-limit buckets",
    }


def main() -> int:
    try:
        payload = collect()
    except CollectorError as exc:
        payload = {
            "available": False,
            "loading": False,
            "stale": False,
            "updatedAt": None,
            "plan": None,
            "quotas": [],
            "resetCreditsAvailable": None,
            "error": str(exc),
        }
    except Exception:
        payload = {
            "available": False,
            "loading": False,
            "stale": False,
            "updatedAt": None,
            "plan": None,
            "quotas": [],
            "resetCreditsAvailable": None,
            "error": "Codex quota collector failed unexpectedly",
        }
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
