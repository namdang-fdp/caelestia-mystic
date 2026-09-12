#!/usr/bin/env python3
"""Capture only normalized Antigravity quota fields, then render/chain stdout."""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


MAX_PAYLOAD_BYTES = 4 * 1024 * 1024


def finite_number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) else None


def cache_path() -> Path:
    base = os.environ.get("XDG_CACHE_HOME")
    root = Path(base).expanduser() if base else Path.home() / ".cache"
    return root / "caelestia-ai-usage" / "antigravity.json"


def normalize(payload: dict[str, Any]) -> dict[str, Any] | None:
    raw_quotas = payload.get("quota")
    if not isinstance(raw_quotas, dict):
        return None

    quotas: list[dict[str, Any]] = []
    for raw_id, raw_quota in raw_quotas.items():
        if not isinstance(raw_id, str) or not isinstance(raw_quota, dict):
            continue
        fraction = finite_number(raw_quota.get("remaining_fraction"))
        if fraction is None:
            continue
        reset_in = finite_number(raw_quota.get("reset_in_seconds"))
        reset_time = raw_quota.get("reset_time")
        quotas.append(
            {
                "id": raw_id[:128],
                "remainingPercent": round(max(0.0, min(1.0, fraction)) * 100.0, 2),
                "resetTime": reset_time[:80] if isinstance(reset_time, str) else None,
                "resetInSeconds": max(0, int(reset_in)) if reset_in is not None else None,
            }
        )

    if not quotas:
        return None
    quotas.sort(key=lambda quota: quota["id"])
    plan = payload.get("plan_tier")
    return {
        "updatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "planTier": plan[:80] if isinstance(plan, str) and plan.strip() else None,
        "quotas": quotas,
    }


def atomic_write(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".antigravity-", suffix=".json", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, separators=(",", ":"))
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def original_command(config_path: str | None) -> str | None:
    if not config_path:
        return None
    try:
        config = json.loads(Path(config_path).expanduser().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    command = config.get("originalCommand") if isinstance(config, dict) else None
    return command if isinstance(command, str) and command.strip() else None


def fallback_statusline(payload: dict[str, Any], normalized: dict[str, Any] | None) -> str:
    plan = payload.get("plan_tier")
    plan_label = plan.strip() if isinstance(plan, str) and plan.strip() else "Antigravity"
    if normalized and normalized["quotas"]:
        quota = normalized["quotas"][0]
        remaining = quota["remainingPercent"]
        formatted = f"{remaining:.0f}" if abs(remaining - round(remaining)) < 0.05 else f"{remaining:.1f}"
        return f"{plan_label} · {formatted}% quota left"
    return f"{plan_label} · quota sync pending"


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--chain-config")
    args, _ = parser.parse_known_args()

    raw = sys.stdin.buffer.read(MAX_PAYLOAD_BYTES + 1)
    if len(raw) > MAX_PAYLOAD_BYTES:
        raw = b"{}"
    try:
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            payload = {}
    except (json.JSONDecodeError, UnicodeDecodeError):
        payload = {}

    normalized = normalize(payload)
    if normalized is not None:
        try:
            atomic_write(cache_path(), normalized)
        except OSError:
            # A status line must remain usable even when its optional cache is
            # temporarily unwritable. No input data is echoed to diagnostics.
            pass

    command = original_command(args.chain_config)
    if command:
        completed = subprocess.run(
            command,
            shell=True,
            executable="/bin/sh",
            input=raw,
            stdout=sys.stdout.buffer,
            stderr=sys.stderr.buffer,
            check=False,
        )
        return completed.returncode

    sys.stdout.write(fallback_statusline(payload, normalized) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
