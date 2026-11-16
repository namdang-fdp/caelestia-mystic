#!/usr/bin/env python3
"""Per-app RAM/CPU snapshot read from /proc, printed as JSON (or a table).

Used by the resources drawer. Stdlib only, Linux only.
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

DELETED = " (deleted)"


def _read(path: Path) -> str:
    return path.read_text(errors="replace")


def _kb_fields(text: str) -> dict:
    fields = {}
    for line in text.splitlines():
        key, _, rest = line.partition(":")
        parts = rest.split()
        if parts and parts[0].isdigit():
            fields[key.strip()] = int(parts[0])
    return fields


def read_meminfo(proc: Path) -> dict:
    try:
        f = _kb_fields(_read(proc / "meminfo"))
    except OSError:
        f = {}
    swap_total = f.get("SwapTotal", 0)
    return {
        "total_kb": f.get("MemTotal", 0),
        "available_kb": f.get("MemAvailable", 0),
        "swap_total_kb": swap_total,
        "swap_used_kb": max(0, swap_total - f.get("SwapFree", 0)),
    }


def _parse_stat(text: str):
    """(comm, ticks, start_ticks). Splits after the LAST ")" since comm may hold anything."""
    left, right = text.index("("), text.rindex(")")
    rest = text[right + 2:].split()
    return text[left + 1:right], int(rest[11]) + int(rest[12]), int(rest[19])


def _link(path: Path) -> str:
    try:
        return os.readlink(path)
    except OSError:
        return ""


def _uptime(proc: Path) -> float:
    try:
        return float(_read(proc / "uptime").split()[0])
    except (OSError, ValueError, IndexError):
        return 0.0


def read_processes(proc: Path, clk_tck: int = None, with_pss: bool = True) -> list:
    clk_tck = clk_tck or os.sysconf("SC_CLK_TCK")
    uptime = _uptime(proc)
    found = []
    try:
        entries = list(proc.iterdir())
    except OSError:
        return found
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            comm, ticks, start = _parse_stat(_read(entry / "stat"))
        except (OSError, ValueError, IndexError):
            continue
        status = {}
        try:
            status = _kb_fields(_read(entry / "status"))
        except OSError:
            pass
        pss = 0
        if with_pss:
            try:
                pss = _kb_fields(_read(entry / "smaps_rollup")).get("Pss", 0)
            except OSError:
                pass
        exe = _link(entry / "exe")
        if exe.endswith(DELETED):
            exe = exe[: -len(DELETED)]
        cwd = _link(entry / "cwd")
        orphan = cwd.endswith(DELETED)
        if orphan:
            cwd = cwd[: -len(DELETED)]
        found.append({
            "pid": int(entry.name), "name": comm, "exe": exe,
            "rss_kb": status.get("VmRSS", 0), "pss_kb": pss, "ticks": ticks,
            "age_s": max(0.0, uptime - start / clk_tck), "cwd": cwd, "orphan": orphan,
        })
    return found


def group_name(exe: str, comm: str) -> str:
    base = os.path.basename(exe) if exe else comm
    if base == "zen-bin":
        return "Zen"
    if base == "claude-desktop":
        return "Claude Desktop"
    if base == "claude":
        return "Claude"
    if base.startswith("electron"):
        return "Electron"
    if base.startswith("codex"):
        return "Codex"
    return base


def cpu_percent(before: dict, after: dict, dt_s: float, clk_tck: int) -> dict:
    out = {}
    for pid, ticks in after.items():
        if pid in before:
            delta = max(0, ticks - before[pid])
            out[pid] = delta / clk_tck / dt_s * 100 if dt_s > 0 else 0.0
    return out


def _cpu_times(proc: Path):
    try:
        parts = [int(x) for x in _read(proc / "stat").splitlines()[0].split()[1:]]
    except (OSError, ValueError, IndexError):
        return 0, 0
    return sum(parts), parts[3] + (parts[4] if len(parts) > 4 else 0)


def collect(proc: Path = Path("/proc"), interval: float = 0.3, sleep=time.sleep, clk_tck: int = None) -> dict:
    clk_tck = clk_tck or os.sysconf("SC_CLK_TCK")
    before = read_processes(proc, clk_tck, with_pss=False)
    total0, idle0 = _cpu_times(proc)
    t0 = time.monotonic()
    sleep(interval)
    dt = time.monotonic() - t0
    after = read_processes(proc, clk_tck)
    total1, idle1 = _cpu_times(proc)

    cpu = cpu_percent({p["pid"]: p["ticks"] for p in before}, {p["pid"]: p["ticks"] for p in after}, dt, clk_tck)
    dtotal = total1 - total0
    system_cpu = max(0.0, (1 - (idle1 - idle0) / dtotal) * 100) if dtotal > 0 else 0.0

    mem = read_meminfo(proc)
    groups = {}
    claude = []
    for p in after:
        name = group_name(p["exe"], p["name"])
        ram = p["pss_kb"] or p["rss_kb"]
        g = groups.setdefault(name, {"name": name, "ram_kb": 0, "cpu_percent": 0.0, "count": 0})
        g["ram_kb"] += ram
        g["cpu_percent"] += cpu.get(p["pid"], 0.0)
        g["count"] += 1
        if name == "Claude":
            claude.append({"pid": p["pid"], "cwd": p["cwd"], "project": os.path.basename(p["cwd"]),
                           "age_s": p["age_s"], "ram_kb": ram, "orphan": p["orphan"]})
    return {
        "system": {"total_kb": mem["total_kb"], "used_kb": max(0, mem["total_kb"] - mem["available_kb"]),
                   "swap_total_kb": mem["swap_total_kb"], "swap_used_kb": mem["swap_used_kb"],
                   "cpu_percent": system_cpu},
        "groups": sorted(groups.values(), key=lambda g: (-g["ram_kb"], g["name"])),
        "claude": claude,
    }


def _gb(kb: int) -> str:
    return f"{kb / 1048576:.1f} GB" if kb >= 1048576 else f"{kb // 1024} MB"


def _table(data: dict) -> str:
    s = data["system"]
    lines = [f"RAM {_gb(s['used_kb'])} / {_gb(s['total_kb'])}   swap {_gb(s['swap_used_kb'])} / {_gb(s['swap_total_kb'])}   CPU {s['cpu_percent']:.0f}%", ""]
    lines += [f"{g['name']:<18}{_gb(g['ram_kb']):>10}{g['cpu_percent']:>7.0f}%{g['count']:>5}p" for g in data["groups"][:12]]
    if data["claude"]:
        lines.append("")
        lines += [f"claude {c['pid']:<8}{_gb(c['ram_kb']):>9}  {c['project'] or '-'}{'  ORPHAN' if c['orphan'] else ''}" for c in data["claude"]]
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--table", action="store_true")
    parser.add_argument("--interval", type=float, default=0.3)
    args = parser.parse_args(argv)
    data = collect(interval=args.interval)
    print(_table(data) if args.table else json.dumps(data))
    return 0


if __name__ == "__main__":
    sys.exit(main())
