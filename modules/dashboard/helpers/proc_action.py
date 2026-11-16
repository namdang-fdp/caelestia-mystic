#!/usr/bin/env python3
"""Stop one of your own processes, but only if it is still the process you looked at.

    proc_action.py stop <pid> <start_ticks>

Prints {"ok": bool, "error": str}. SIGTERM only. It refuses unless the pid still has the same
start time (the pid was not reused), belongs to you, is not pid 1 or this helper's own
ancestry, and is not on the protected list.
"""
import json
import os
import signal
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proc_top import _parse_stat  # noqa: E402

PROTECTED = frozenset({
    "Hyprland", "hyprland", "quickshell", "qs", "systemd", "pipewire", "pipewire-pulse",
    "wireplumber", "dbus-daemon", "dbus-broker", "Xwayland",
})


def check(pid: int, start: int, proc: Path = Path("/proc"), uid: int = None, self_pids: tuple = None) -> str:
    """"" when the process may be stopped, else a short reason."""
    uid = os.getuid() if uid is None else uid
    self_pids = (os.getpid(), os.getppid()) if self_pids is None else self_pids
    if pid <= 1 or pid in self_pids:
        return "system"
    entry = proc / str(pid)
    try:
        comm, _ticks, started = _parse_stat((entry / "stat").read_text(errors="replace"))
        owner = entry.stat().st_uid
    except (OSError, ValueError, IndexError):
        return "gone"
    if started != start:
        return "changed"
    if owner != uid:
        return "not yours"
    try:
        exe = os.path.basename(os.readlink(entry / "exe")).removesuffix(" (deleted)")
    except OSError:
        exe = ""
    if comm in PROTECTED or exe in PROTECTED:
        return "protected"
    return ""


def stop(pid: int, start: int, proc: Path = Path("/proc"), uid: int = None, kill=os.kill, self_pids: tuple = None) -> dict:
    reason = check(pid, start, proc, uid, self_pids)
    if reason:
        return {"ok": False, "error": reason}
    try:
        kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return {"ok": False, "error": "gone"}
    except PermissionError:
        return {"ok": False, "error": "not yours"}
    return {"ok": True, "error": ""}


def main(argv=None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 3 or args[0] != "stop" or not args[1].lstrip("-").isdigit() or not args[2].isdigit():
        print(json.dumps({"ok": False, "error": "usage"}))
        return 2
    result = stop(int(args[1]), int(args[2]))
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
