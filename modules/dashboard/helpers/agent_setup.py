#!/usr/bin/env python3
"""Install or remove the island's hooks for Claude Code or Gemini CLI.

    agent_setup.py status|install|uninstall [claude|gemini]

Only entries whose command mentions agent_hook.py are ever added or removed;
everything else in settings.json is preserved. A timestamped backup is written
before every change. Codex is not touched: its sessions are read from logs.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import time
from pathlib import Path

MARKER = "agent_hook.py"
EVENTS = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Notification", "Stop", "SessionEnd"]
# Gemini CLI's hook events (experimental: follows its documented names).
GEMINI_EVENTS = ["BeforeAgent", "BeforeTool", "AfterTool", "Notification", "AfterAgent", "SessionEnd"]
TARGETS = {
    "claude": {"path": ".claude/settings.json", "events": EVENTS, "env": "CLAUDE_SETTINGS", "binary": "claude"},
    "gemini": {"path": ".gemini/settings.json", "events": GEMINI_EVENTS, "env": "GEMINI_SETTINGS", "binary": "gemini"},
}


def settings_path(target="claude") -> Path:
    info = TARGETS[target]
    return Path(os.environ.get(info["env"]) or Path.home() / info["path"])


def hook_command(agent="claude") -> str:
    script = Path(__file__).with_name("agent_hook.py")
    return f"python3 -I {script} {agent}"


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
    installed = all(any(is_ours(g) for g in hooks.get(e, [])) for e in events)
    return {"installed": installed, "claude": installed, "available": shutil.which(binary) is not None or path.parent.exists()}


def write(path: Path, data: dict) -> None:
    if path.exists():
        shutil.copy2(path, path.with_name(f"{path.name}.bak-island-{time.strftime('%Y%m%d-%H%M%S')}"))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    os.replace(temporary, path)


def install(path: Path, events=EVENTS, agent="claude") -> None:
    data = load(path)
    hooks = data.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("hooks is not an object")
    for event in events:
        groups = [g for g in hooks.get(event, []) if not is_ours(g)]
        groups.append({"hooks": [{"type": "command", "command": hook_command(agent), "timeout": 5}]})
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
