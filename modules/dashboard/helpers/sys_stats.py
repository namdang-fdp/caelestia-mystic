#!/usr/bin/env python3
"""GPU clock and disk usage/throughput for the resources drawer's System tab.

Prints {"gpu": {"cur_mhz", "max_mhz"} | null, "disk": {"total_kb", "used_kb", "read_bps", "write_bps"}}.
The GPU figure is a clock, not utilisation: the i915 driver exposes no busy counter without root.
"""
import json
import os
import re
import sys
import time
from pathlib import Path

CARD = re.compile(r"card\d+$")
SECTOR = 512


def _int(path: Path):
    try:
        return int(path.read_text().split()[0])
    except (OSError, ValueError, IndexError):
        return None


def read_gpu(sys_root: Path = Path("/sys")):
    try:
        cards = sorted(p for p in (sys_root / "class/drm").iterdir() if CARD.match(p.name))
    except OSError:
        return None
    for card in cards:
        cur, top = _int(card / "gt_cur_freq_mhz"), _int(card / "gt_max_freq_mhz")
        if cur is not None and top is not None:
            return {"cur_mhz": cur, "max_mhz": top}
    return None


def whole_disk(name: str) -> str:
    m = re.match(r"^((?:nvme\d+n\d+|mmcblk\d+))p\d+$", name) or re.match(r"^([a-z]+)\d+$", name)
    return m.group(1) if m else name


def _root_disk(proc: Path, mount: str):
    try:
        for line in (proc / "mounts").read_text().splitlines():
            parts = line.split()
            if len(parts) > 1 and parts[1] == mount and parts[0].startswith("/dev/"):
                return whole_disk(os.path.basename(parts[0]))
    except OSError:
        pass
    return None


def _sectors(proc: Path, disk):
    """(sectors read, sectors written) of one disk, or None."""
    if not disk:
        return None
    try:
        for line in (proc / "diskstats").read_text().splitlines():
            f = line.split()
            if len(f) > 9 and f[2] == disk:
                return int(f[5]), int(f[9])
    except (OSError, ValueError):
        pass
    return None


def collect(sys_root: Path = Path("/sys"), proc: Path = Path("/proc"), root: str = "/",
            interval: float = 0.3, sleep=time.sleep, mount: str = "/") -> dict:
    """root: path measured with statvfs; mount: mount point whose disk's throughput is reported."""
    disk = _root_disk(proc, mount)
    before = _sectors(proc, disk)
    sleep(interval)
    after = _sectors(proc, disk)
    read_bps = write_bps = 0
    if before and after and interval > 0:
        read_bps = max(0, after[0] - before[0]) * SECTOR / interval
        write_bps = max(0, after[1] - before[1]) * SECTOR / interval
    try:
        st = os.statvfs(root)
        total_kb = st.f_blocks * st.f_frsize // 1024
        used_kb = (st.f_blocks - st.f_bfree) * st.f_frsize // 1024
    except OSError:
        total_kb = used_kb = 0
    return {"gpu": read_gpu(sys_root),
            "disk": {"total_kb": total_kb, "used_kb": used_kb, "read_bps": read_bps, "write_bps": write_bps}}


if __name__ == "__main__":
    print(json.dumps(collect()))
    sys.exit(0)
