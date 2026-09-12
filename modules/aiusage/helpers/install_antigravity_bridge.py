#!/usr/bin/env python3
"""Install the quota bridge without discarding an existing statusline command."""

from __future__ import annotations

import json
import os
import shlex
import tempfile
from pathlib import Path
from typing import Any


def atomic_json(path: Path, payload: Any, mode: int) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, ensure_ascii=False)
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


def main() -> int:
    home = Path.home()
    settings_path = home / ".gemini" / "antigravity-cli" / "settings.json"
    config_base = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")).expanduser()
    chain_path = config_base / "caelestia-ai-usage" / "antigravity-statusline.json"
    bridge_path = Path(__file__).resolve().with_name("antigravity_statusline.py")
    bridge_command = shlex.join(
        ["python3", str(bridge_path), "--chain-config", str(chain_path)]
    )

    if settings_path.exists():
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
        if not isinstance(settings, dict):
            raise SystemExit("Antigravity settings root must be a JSON object")
        settings_mode = settings_path.stat().st_mode & 0o777
    else:
        settings = {}
        settings_mode = 0o600

    statusline = settings.get("statusLine")
    statusline = dict(statusline) if isinstance(statusline, dict) else {}
    current = statusline.get("command")
    current = current if isinstance(current, str) and current.strip() else None
    is_our_bridge = current is not None and "antigravity_statusline.py" in current
    original = None if is_our_bridge else current

    # This file contains only the pre-existing user command needed for chaining;
    # no status payload, identity, token, or conversation data is stored here.
    atomic_json(chain_path, {"originalCommand": original}, 0o600)

    statusline["type"] = "command"
    statusline["command"] = bridge_command
    if "enabled" not in statusline:
        statusline["enabled"] = True
    settings["statusLine"] = statusline
    atomic_json(settings_path, settings, settings_mode or 0o600)

    print(
        json.dumps(
            {
                "installed": True,
                "chainedExistingCommand": original is not None,
                "settingsPath": str(settings_path),
                "cachePath": str(
                    Path(os.environ.get("XDG_CACHE_HOME", home / ".cache"))
                    / "caelestia-ai-usage"
                    / "antigravity.json"
                ),
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
