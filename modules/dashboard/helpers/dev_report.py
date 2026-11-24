#!/usr/bin/env python3
"""Time per project, the commit streak and a standup draft, from files already on disk.

    dev_report.py report      -> {"time": [...], "streak": {...}}
    dev_report.py standup     -> {"text": "..."}

Active time comes from the Claude Code and Codex transcripts: within a session,
the gaps between consecutive events are added up, each capped at five minutes,
and grouped by the git repository the session ran in. Commits come from
`git log --author=<your email>` in those repositories plus the projects Codex
trusts. Nothing leaves the machine and nothing is written.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

GAP_CAP = 300
MAX_REPOS = 25
SKIP_NAMES = {"", "/", "home"}


def parse_time(value) -> float | None:
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def intervals(stamps, cap: int = GAP_CAP) -> list:
    """One (start, end) per pair of consecutive events of a session; a gap longer than
    `cap` only counts for `cap` seconds. Gaps are never bridged between sessions."""
    ordered = sorted(stamps)
    return [(a, a + min(b - a, cap)) for a, b in zip(ordered, ordered[1:]) if b > a]


def union_seconds(spans, start: float, end: float) -> int:
    """Total length of the spans clipped to [start, end), overlapping ones counted once."""
    clipped = sorted((max(a, start), min(b, end)) for a, b in spans if b > start and a < end)
    total, cursor = 0.0, start
    for a, b in clipped:
        a = max(a, cursor)
        if b > a:
            total += b - a
            cursor = b
    return int(total)


def active_seconds(stamps, start: float, end: float, cap: int = GAP_CAP) -> int:
    return union_seconds(intervals(stamps, cap), start, end)


SCRATCH = re.compile(r"/scratch-workspaces/|/\.claude/worktrees/\.?tmp")


def worktree_main(git_file: Path) -> str:
    """The main repository of a linked worktree (its .git is a file pointing into the main .git)."""
    try:
        target = git_file.read_text().split("gitdir:", 1)[1].strip()
    except (OSError, IndexError):
        return ""
    marker = "/.git/worktrees/"
    return target.split(marker, 1)[0] if marker in target else ""


def git_root(path: str, home: str) -> str:
    p = Path(path)
    for candidate in [p, *p.parents]:
        if str(candidate) == home:
            break
        dot_git = candidate / ".git"
        if dot_git.is_file():
            return worktree_main(dot_git) or str(candidate)
        if dot_git.exists():
            return str(candidate)
    return path


def session_files(home: Path, since: float):
    for root, pattern in ((home / ".claude" / "projects", "*.jsonl"), (home / ".codex" / "sessions", "rollout-*.jsonl")):
        if root.is_dir():
            for path in root.rglob(pattern):
                try:
                    if path.stat().st_mtime >= since:
                        yield path
                except OSError:
                    continue


def read_session(path: Path, since: float):
    """(cwd, [timestamps]) of one transcript; timestamps older than `since` dropped."""
    cwd, stamps = "", []
    try:
        with path.open(errors="replace") as handle:
            for line in handle:
                if '"timestamp"' not in line:
                    continue
                try:
                    row = json.loads(line)
                except ValueError:
                    continue
                stamp = parse_time(row.get("timestamp"))
                if stamp is not None and stamp >= since:
                    stamps.append(stamp)
                if not cwd:
                    payload = row.get("payload") if isinstance(row.get("payload"), dict) else {}
                    cwd = str(row.get("cwd") or payload.get("cwd") or "")
    except OSError:
        pass
    return cwd, stamps


def activity(home: Path, since: float) -> dict:
    """repo path -> activity spans of every recent session in it (see `intervals`)."""
    result: dict[str, list] = {}
    for path in session_files(home, since):
        cwd, stamps = read_session(path, since)
        if cwd and stamps:
            result.setdefault(git_root(cwd, str(home)), []).extend(intervals(stamps))
    return {k: v for k, v in result.items() if Path(k).name not in SKIP_NAMES and k != str(home)}


def projects(acts: dict) -> dict:
    """Activity worth reporting: Claude Desktop scratch folders are throwaway work."""
    return {k: v for k, v in acts.items() if not SCRATCH.search(k)}


def midnight(now: float) -> float:
    d = datetime.fromtimestamp(now)
    return datetime(d.year, d.month, d.day).timestamp()


def time_report(acts: dict, now: float) -> list[dict]:
    today = midnight(now)
    rows = []
    for repo, stamps in projects(acts).items():
        t, w = union_seconds(stamps, today, now + 1), union_seconds(stamps, today - 6 * 86400, now + 1)
        if w:
            rows.append({"name": Path(repo).name, "path": repo, "today": t, "week": w})
    return sorted(rows, key=lambda r: (-r["today"], -r["week"]))


def trusted_repos(home: Path) -> list[str]:
    try:
        text = (home / ".codex" / "config.toml").read_text()
    except OSError:
        return []
    paths = re.findall(r'^\[projects\."([^"]+)"\]', text, re.M)
    return [p for p in paths if p != str(home) and (Path(p) / ".git").exists()]


def repo_universe(home: Path, acts: dict) -> list[str]:
    """Repositories with agent activity, then the projects Codex trusts. Activity in a
    folder that is not a repository still counts for time, just without commits."""
    seen, out = set(), []
    for repo in [*projects(acts), *trusted_repos(home)]:
        if repo not in seen and Path(repo).is_dir():
            seen.add(repo)
            out.append(repo)
    return out[:MAX_REPOS]


def author_email(run=subprocess.run) -> str:
    try:
        return run(["git", "config", "--global", "user.email"], capture_output=True, text=True, timeout=3).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def commits(repo: str, since: float, until: float, email: str, fmt: str = "%s", run=subprocess.run) -> list[str]:
    if not email:
        return []
    try:
        out = run(["git", "-C", repo, "log", f"--since={int(since)}", f"--until={int(until)}", f"--author={email}", "--no-merges", f"--pretty=format:{fmt}"],
                  capture_output=True, text=True, timeout=6)
    except (OSError, subprocess.SubprocessError):
        return []
    return [l for l in out.stdout.splitlines() if l.strip()] if out.returncode == 0 else []


def streak_days(days: set, today: str) -> int:
    """Consecutive active days ending today; a day without activity yet does not break it."""
    d = datetime.strptime(today, "%Y-%m-%d").date()
    if today not in days:
        d -= timedelta(days=1)
    count = 0
    while d.isoformat() in days:
        count += 1
        d -= timedelta(days=1)
    return count


# Level follows how many of the last 90 days had a commit or agent activity.
LEVELS = [0, 3, 7, 14, 21, 30, 45, 60, 75, 90]


def level_for(points: int) -> dict:
    level = max(i for i, need in enumerate(LEVELS) if points >= need) + 1
    nxt = LEVELS[level] if level < len(LEVELS) else None
    return {"level": level, "points": points, "next": nxt}


def streak_report(repos: list, acts: dict, now: float, email: str, run=subprocess.run) -> dict:
    days, total = set(), 0
    for repo in repos:
        out = commits_dates(repo, now, email, run)
        total += len(out)
        days.update(out)
    active_days = set()
    for spans in acts.values():
        active_days.update(datetime.fromtimestamp(a).date().isoformat() for a, _ in spans)
    days |= active_days
    today = datetime.fromtimestamp(now).date().isoformat()
    return {"streak": streak_days(days, today), "commits": total, "activeDays": len(days), **level_for(len(days))}


def commits_dates(repo: str, now: float, email: str, run=subprocess.run) -> list[str]:
    if not email:
        return []
    try:
        out = run(["git", "-C", repo, "log", f"--since={int(now - 90 * 86400)}", f"--author={email}", "--no-merges", "--date=short", "--pretty=format:%ad"],
                  capture_output=True, text=True, timeout=6)
    except (OSError, subprocess.SubprocessError):
        return []
    return [l for l in out.stdout.splitlines() if re.fullmatch(r"\d{4}-\d{2}-\d{2}", l)] if out.returncode == 0 else []


def duration(seconds: int) -> str:
    m = int(seconds) // 60
    return f"{m // 60}h {m % 60:02d}m" if m >= 60 else f"{m}m"


def standup_text(repos: list, acts: dict, now: float, email: str, run=subprocess.run) -> str:
    today = midnight(now)
    windows = (("Yesterday", today - 86400, today), ("Today", today, now + 1))
    lines = [f"Standup · {datetime.fromtimestamp(now).strftime('%a %d %b')}"]
    for title, start, end in windows:
        lines.append(title)
        rows = []
        for repo in repos:
            subjects = commits(repo, start, end, email, run=run)
            seconds = union_seconds(acts.get(repo, []), start, end)
            if subjects or seconds >= 600:
                parts = []
                if subjects:
                    shown = ", ".join(s[:70] for s in subjects[:4]) + (f", +{len(subjects) - 4} more" if len(subjects) > 4 else "")
                    parts.append(f"{len(subjects)} commit{'s' if len(subjects) != 1 else ''} ({shown})")
                if seconds >= 600:
                    parts.append(f"{duration(seconds)} with agents")
                rows.append(f"- {Path(repo).name}: " + " · ".join(parts))
        lines.extend(rows or ["- Nothing recorded"])
    return "\n".join(lines) + "\n\n"


def main(argv, home: Path = Path.home(), now: float | None = None) -> dict:
    now = time.time() if now is None else now
    action = argv[1] if len(argv) > 1 else ""
    since = midnight(now) - 6 * 86400
    acts = activity(home, since)
    if action == "report":
        email = author_email()
        repos = repo_universe(home, acts)
        return {"time": time_report(acts, now), "streak": streak_report(repos, acts, now, email)}
    if action == "standup":
        return {"text": standup_text(repo_universe(home, acts), acts, now, author_email())}
    raise ValueError("usage: report | standup")


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv)))
    except Exception as error:
        print(json.dumps({"error": str(error)[:120]}))
        sys.exit(1)
