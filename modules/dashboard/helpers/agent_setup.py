#!/usr/bin/env python3
"""Install or remove local agent activity hooks.

    agent_setup.py status|install|uninstall [claude|codex|gemini]

Only entries whose command mentions agent_hook.py are ever added or removed;
everything else in settings.json is preserved. A timestamped backup is written
before every change. Codex hooks report state and leave approvals to Codex.
"""

from __future__ import annotations

import json
import os
import shlex
import shutil
import stat
import sys
import time
from pathlib import Path

MARKER = "agent_hook.py"
EVENTS = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Notification", "Stop", "SessionEnd"]
# Gemini CLI's hook events (experimental: follows its documented names).
GEMINI_EVENTS = ["BeforeAgent", "BeforeTool", "AfterTool", "Notification", "AfterAgent", "SessionEnd"]
CODEX_EVENTS = ["PermissionRequest", "PostToolUse", "Stop", "Interrupt", "SessionEnd"]
TARGETS = {
    "claude": {"path": ".claude/settings.json", "events": EVENTS, "env": "CLAUDE_SETTINGS", "binary": "claude"},
    "gemini": {"path": ".gemini/settings.json", "events": GEMINI_EVENTS, "env": "GEMINI_SETTINGS", "binary": "gemini"},
    "codex": {"path": ".codex/hooks.json", "events": CODEX_EVENTS, "env": "CODEX_HOOKS", "binary": "codex"},
}


def settings_path(target="claude") -> Path:
    info = TARGETS[target]
    if target == "codex" and os.environ.get("CODEX_HOME") and not os.environ.get(info["env"]):
        return Path(os.environ["CODEX_HOME"]) / "hooks.json"
    return Path(os.environ.get(info["env"]) or Path.home() / info["path"])


def hook_command(agent="claude") -> str:
    script = Path(__file__).with_name("agent_hook.py")
    return f"python3 -I {shlex.quote(str(script))} {agent}"


# PermissionRequest waits for the island's answer, so it needs far longer than the rest.
TIMEOUTS = {"PermissionRequest": 330}
DEFAULT_TIMEOUT = 5


def expected_timeout(event: str, agent="claude") -> int:
    if agent == "codex" and event == "Interrupt":
        return 1
    return TIMEOUTS.get(event, DEFAULT_TIMEOUT) if agent == "claude" else DEFAULT_TIMEOUT


def is_current(group, event: str, agent="claude") -> bool:
    """Ours, with the timeout this version expects (older installs get upgraded)."""
    return is_ours(group) and any(
        MARKER in str(h.get("command", "")) and h.get("timeout") == expected_timeout(event, agent)
        for h in group.get("hooks", []) if isinstance(h, dict))


def is_ours(group) -> bool:
    return isinstance(group, dict) and any(MARKER in str(h.get("command", "")) for h in group.get("hooks", []) if isinstance(h, dict))


def load(path: Path) -> dict:
    if not path.exists():
        return {}
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError("settings.json is not an object")
    return data


def status(path: Path, events=EVENTS, binary="claude") -> dict:
    try:
        hooks = load(path).get("hooks") or {}
    except (OSError, ValueError):
        return {"installed": False, "claude": False, "error": "unreadable"}
    installed = all(any(is_current(g, e, binary) for g in hooks.get(e, [])) for e in events)
    return {"installed": installed, "claude": installed, "available": shutil.which(binary) is not None or path.parent.exists()}


def write(path: Path, data: dict) -> None:
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    if path.exists():
        shutil.copy2(path, path.with_name(f"{path.name}.bak-island-{time.strftime('%Y%m%d-%H%M%S')}"))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    temporary.chmod(mode)
    os.replace(temporary, path)


def install(path: Path, events=EVENTS, agent="claude") -> None:
    data = load(path)
    hooks = data.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("hooks is not an object")
    for event in events:
        groups = [g for g in hooks.get(event, []) if not is_ours(g)]
        groups.append({"hooks": [{"type": "command", "command": hook_command(agent), "timeout": expected_timeout(event, agent)}]})
        hooks[event] = groups
    write(path, data)


def uninstall(path: Path) -> None:
    data = load(path)
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return
    for event in list(hooks):
        groups = [g for g in hooks[event] if not is_ours(g)]
        if groups:
            hooks[event] = groups
        else:
            del hooks[event]
    write(path, data)


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    target = sys.argv[2] if len(sys.argv) > 2 else "claude"
    try:
        if target not in TARGETS:
            raise ValueError(f"unknown agent {target}")
        info = TARGETS[target]
        path = settings_path(target)
        if action == "install":
            install(path, info["events"], target)
        elif action == "uninstall":
            uninstall(path)
        elif action != "status":
            raise ValueError(f"unknown action {action}")
        print(json.dumps({"target": target, **status(path, info["events"], info["binary"])}))
        return 0
    except Exception as error:
        print(json.dumps({"target": target, "installed": False, "claude": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
