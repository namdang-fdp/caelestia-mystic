import json, os, sys, tempfile, unittest
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0, os.path.dirname(__file__))
import dev_report as report

NOON = datetime(2026, 11, 15, 12, 0).timestamp()
MID = datetime(2026, 11, 15).timestamp()


def iso(ts):
    return datetime.fromtimestamp(ts).astimezone().isoformat()


class MathTests(unittest.TestCase):
    def test_gaps_are_capped_and_the_window_is_respected(self):
        stamps = [0, 60, 120, 1000, 1010]  # 60 + 60 + 300(cap of 880) + 10
        self.assertEqual(report.active_seconds(stamps, 0, 5000), 430)
        self.assertEqual(report.active_seconds(stamps, 100, 5000), 20 + 300 + 10)
        self.assertEqual(report.active_seconds([5], 0, 10), 0)

    def test_overlapping_sessions_are_counted_once(self):
        a = report.intervals([0, 100, 200])
        b = report.intervals([50, 150, 250])
        self.assertEqual(report.union_seconds(a + b, 0, 1000), 250)

    def test_streak_survives_a_day_that_has_not_started_yet(self):
        days = {"2026-11-12", "2026-11-13", "2026-11-14"}
        self.assertEqual(report.streak_days(days, "2026-11-15"), 3)
        self.assertEqual(report.streak_days(days | {"2026-11-15"}, "2026-11-15"), 4)
        self.assertEqual(report.streak_days({"2026-11-10"}, "2026-11-15"), 0)
        self.assertEqual(report.streak_days(set(), "2026-11-15"), 0)

    def test_levels_rise_with_active_days(self):
        self.assertEqual(report.level_for(0)["level"], 1)
        self.assertEqual(report.level_for(7), {"level": 3, "points": 7, "next": 14})
        self.assertIsNone(report.level_for(500)["next"])


class RootTests(unittest.TestCase):
    def test_linked_worktrees_belong_to_their_main_repository(self):
        with tempfile.TemporaryDirectory() as t:
            main = Path(t) / "app"; (main / ".git" / "worktrees" / "feat").mkdir(parents=True)
            wt = Path(t) / "wt"; (wt / "src").mkdir(parents=True)
            (wt / ".git").write_text(f"gitdir: {main}/.git/worktrees/feat\n")
            self.assertEqual(report.git_root(str(wt / "src"), "/nowhere"), str(main))
            self.assertEqual(report.git_root(str(main), "/nowhere"), str(main))

    def test_home_is_never_a_project(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t); (home / ".git").mkdir()
            self.assertEqual(report.git_root(str(home / "x"), str(home)), str(home / "x"))


class ScanTests(unittest.TestCase):
    def write(self, path, rows):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
        os.utime(path, (NOON, NOON))

    def test_claude_and_codex_sessions_add_up_per_repo_and_scratch_is_hidden(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t); repo = home / "proj"; (repo / ".git").mkdir(parents=True)
            scratch = home / ".config/Claude/scratch-workspaces/a/b/scratch-x"; scratch.mkdir(parents=True)
            self.write(home / ".claude/projects/p/s.jsonl", [{"timestamp": iso(MID + 3600 + i * 60), "cwd": str(repo)} for i in range(11)])
            self.write(home / ".codex/sessions/2026/11/15/rollout-1.jsonl",
                       [{"timestamp": iso(MID + 7200), "type": "session_meta", "payload": {"cwd": str(repo)}}, {"timestamp": iso(MID + 7260)}])
            self.write(home / ".claude/projects/q/s.jsonl", [{"timestamp": iso(MID + 100 + i * 60), "cwd": str(scratch)} for i in range(5)])
            acts = report.activity(home, MID - 6 * 86400)
            rows = report.time_report(acts, NOON)
            self.assertEqual([r["name"] for r in rows], ["proj"])
            self.assertEqual(rows[0]["today"], 600 + 60)
            self.assertNotIn(str(scratch), report.repo_universe(home, acts))


class StandupTests(unittest.TestCase):
    def test_text_lists_commits_and_agent_time_per_day(self):
        with tempfile.TemporaryDirectory() as t:
            repo = Path(t) / "app"; (repo / ".git").mkdir(parents=True)
            acts = {str(repo): report.intervals([MID + 100, MID + 400, MID + 700, MID + 1300, MID + 1900])}
            def run(args, **kw):
                since = [a for a in args if a.startswith("--since=")][0]
                subjects = "feat: add login\nfix: typo\nchore: deps\nfeat: a\nfeat: b\nfeat: c" if int(since.split("=")[1]) >= MID else ""
                return SimpleNamespace(returncode=0, stdout=subjects, stderr="")
            text = report.standup_text([str(repo)], acts, NOON, "me@example.com", run=run)
        self.assertIn("Standup · Sun 15 Nov", text)
        self.assertIn("Yesterday\n- Nothing recorded", text)
        self.assertIn("- app: 6 commits (feat: add login, fix: typo, chore: deps, feat: a, +2 more) · 20m with agents", text)

    def test_no_email_means_no_commits_and_a_missing_git_is_tolerated(self):
        self.assertEqual(report.commits("/x", 0, 1, ""), [])
        boom = lambda *a, **k: (_ for _ in ()).throw(FileNotFoundError())
        self.assertEqual(report.commits("/x", 0, 1, "a@b", run=boom), [])


if __name__ == "__main__":
    unittest.main()
