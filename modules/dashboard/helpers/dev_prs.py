#!/usr/bin/env python3
"""Open pull requests of the signed-in GitHub user, with CI and review state.

Prints JSON: {"prs": [...], "merged": [...], "error": ""}. Three `gh` calls plus
one per open pull request (at most MAX_PRS). Any problem (gh missing, signed
out, offline) yields an empty result with an error code so the island stays quiet.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from datetime import datetime

MAX_PRS = 8
RECENT_DAYS = 45
FAIL = {"FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE", "ERROR"}
OK = {"SUCCESS", "NEUTRAL", "SKIPPED"}


def gh(*args, run=subprocess.run):
    result = run(["gh", *args], capture_output=True, text=True, timeout=25)
    if result.returncode:
        raise RuntimeError(result.stderr.strip()[:200] or "gh failed")
    return json.loads(result.stdout or "null")


def summarize_checks(rollup) -> tuple[str, list[str]]:
    """("none"|"pending"|"passing"|"failing", names of the failing checks)."""
    failing, pending, total = [], False, 0
    for item in rollup or []:
        if not isinstance(item, dict):
            continue
        total += 1
        if item.get("__typename") == "StatusContext":
            state = str(item.get("state") or "").upper()
            name = item.get("context") or "status"
            if state in FAIL:
                failing.append(name)
            elif state not in OK and state != "SUCCESS":
                pending = True
            continue
        name = item.get("name") or "check"
        if str(item.get("status") or "").upper() != "COMPLETED":
            pending = True
            continue
        conclusion = str(item.get("conclusion") or "").upper()
        if conclusion in FAIL:
            failing.append(name)
        elif conclusion not in OK:
            pending = True
    if not total:
        return "none", []
    return ("failing" if failing else "pending" if pending else "passing"), failing[:5]


def fresh(updated: str, now: float) -> bool:
    try:
        return now - datetime.fromisoformat(updated.replace("Z", "+00:00")).timestamp() < RECENT_DAYS * 86400
    except ValueError:
        return False


def collect(run=subprocess.run, now: float | None = None) -> dict:
    now = time.time() if now is None else now
    fields = "number,title,url,repository,isDraft,updatedAt"
    opened = gh("search", "prs", "--author=@me", "--state=open", "--sort", "updated", "--limit", "20", "--json", fields, run=run)
    prs = []
    for item in [i for i in opened or [] if fresh(i.get("updatedAt", ""), now)][:MAX_PRS]:
        repo = (item.get("repository") or {}).get("nameWithOwner", "")
        try:
            detail = gh("pr", "view", str(item["number"]), "--repo", repo, "--json", "statusCheckRollup,reviewDecision,state", run=run) or {}
        except RuntimeError:
            detail = {}
        ci, failing = summarize_checks(detail.get("statusCheckRollup"))
        prs.append({"repo": repo, "name": (item.get("repository") or {}).get("name", ""), "number": item["number"], "title": item.get("title", ""),
                    "url": item.get("url", ""), "draft": bool(item.get("isDraft")), "ci": ci, "failing": failing,
                    "review": str(detail.get("reviewDecision") or "")})
    merged = gh("search", "prs", "--author=@me", "--merged", "--sort", "updated", "--limit", "5", "--json", "number,title,url,repository,closedAt", run=run)
    return {"prs": prs, "merged": [{"repo": (m.get("repository") or {}).get("nameWithOwner", ""), "number": m["number"], "title": m.get("title", ""),
                                    "url": m.get("url", "")} for m in merged or []], "error": ""}


if __name__ == "__main__":
    try:
        print(json.dumps(collect()))
    except Exception as error:
        print(json.dumps({"prs": [], "merged": [], "error": str(error)[:120] or "error"}))
