import json, os, sys, tempfile, unittest
from datetime import datetime, timezone
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import agent_sessions as sessions

NOW = datetime(2026, 11, 10, 12, 0).timestamp()


def iso(t):
    return datetime.fromtimestamp(t, timezone.utc).isoformat().replace("+00:00", "Z")


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.agents = self.home / "agents"
        self.folder = self.home / ".codex/sessions/2026/11/10"
        self.folder.mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def rollout(self, name, last, age, cwd="/home/u/proj"):
        rows = [{"type": "session_meta", "payload": {"id": name, "cwd": cwd}},
                {"timestamp": iso(NOW - age - 5), "type": "event_msg", "payload": {"type": "task_started"}},
                {"timestamp": iso(NOW - age), "type": "event_msg", "payload": {"type": last}}]
        path = self.folder / f"rollout-{name}.jsonl"
        path.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
        os.utime(path, (NOW - age, NOW - age))

    def test_codex_turn_in_progress_is_working_and_completed_is_done(self):
        self.rollout("a", "task_started", 10)
        self.rollout("b", "task_complete", 30)
        got = {s["session"]: s for s in sessions.collect(self.home, self.agents, NOW)}
        self.assertEqual((got["a"]["state"], got["a"]["project"]), ("working", "proj"))
        self.assertEqual(got["b"]["state"], "done")

    def test_stale_codex_logs_are_ignored(self):
        self.rollout("a", "task_started", 600)
        self.rollout("b", "task_complete", 600)
        self.assertEqual(sessions.collect(self.home, self.agents, NOW), [])

    def test_hook_file_wins_over_codex_log_and_claude_files_are_read(self):
        self.rollout("a", "task_started", 10)
        self.agents.mkdir()
        (self.agents / "codex-a.json").write_text(json.dumps({"agent": "codex", "session": "a", "state": "waiting", "updated": NOW}))
        (self.agents / "claude-x.json").write_text(json.dumps({"agent": "claude", "session": "x", "state": "working", "updated": NOW}))
        (self.agents / "broken.json").write_text("{")
        got = sorted((s["agent"], s["state"]) for s in sessions.collect(self.home, self.agents, NOW))
        self.assertEqual(got, [("claude", "working"), ("codex", "waiting")])


if __name__ == "__main__":
    unittest.main()
