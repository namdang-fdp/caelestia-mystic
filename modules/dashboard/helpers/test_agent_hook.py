import json, os, stat, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import agent_hook as hook


class AgentHookTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name) / "agents"

    def tearDown(self):
        self.tmp.cleanup()

    def read(self, name):
        return json.loads((self.dir / name).read_text())

    def test_states_follow_events(self):
        base = {"session_id": "s1", "cwd": "/home/u/proj"}
        hook.record("claude", {**base, "hook_event_name": "PreToolUse"}, self.dir, 100)
        self.assertEqual(self.read("claude-s1.json")["state"], "working")
        hook.record("claude", {**base, "hook_event_name": "PermissionRequest"}, self.dir, 110)
        self.assertEqual(self.read("claude-s1.json")["state"], "waiting")
        hook.record("claude", {**base, "hook_event_name": "Stop"}, self.dir, 120)
        data = self.read("claude-s1.json")
        self.assertEqual((data["state"], data["project"]), ("done", "proj"))

    def test_started_survives_repeated_events_of_same_state(self):
        base = {"session_id": "s1"}
        hook.record("codex", {**base, "hook_event_name": "PreToolUse"}, self.dir, 100)
        hook.record("codex", {**base, "hook_event_name": "PostToolUse"}, self.dir, 150)
        data = self.read("codex-s1.json")
        self.assertEqual((data["started"], data["updated"]), (100, 150))

    def test_notification_kinds(self):
        base = {"session_id": "s1", "hook_event_name": "Notification"}
        self.assertTrue(hook.record("claude", {**base, "notification_type": "permission_prompt"}, self.dir, 1))
        self.assertEqual(self.read("claude-s1.json")["state"], "waiting")
        hook.record("claude", {**base, "notification_type": "idle_prompt"}, self.dir, 2)
        self.assertEqual(self.read("claude-s1.json")["state"], "done")
        self.assertFalse(hook.record("claude", {**base, "notification_type": "auth_success"}, self.dir, 3))

    def test_gemini_events_map_like_claude_ones(self):
        base = {"session_id": "g1"}
        hook.record("gemini", {**base, "hook_event_name": "BeforeTool"}, self.dir, 1)
        self.assertEqual(self.read("gemini-g1.json")["state"], "working")
        hook.record("gemini", {**base, "hook_event_name": "AfterAgent"}, self.dir, 2)
        self.assertEqual(self.read("gemini-g1.json")["state"], "done")

    def test_session_end_removes_file_and_unknown_events_are_ignored(self):
        hook.record("claude", {"session_id": "s1", "hook_event_name": "Stop"}, self.dir, 1)
        hook.record("claude", {"session_id": "s1", "hook_event_name": "SessionEnd"}, self.dir, 2)
        self.assertFalse((self.dir / "claude-s1.json").exists())
        self.assertFalse(hook.record("claude", {"hook_event_name": "Whatever"}, self.dir, 3))

    def test_nothing_sensitive_is_stored_and_permissions_are_private(self):
        hook.record("claude", {"session_id": "s1", "hook_event_name": "PreToolUse", "prompt": "SECRET", "tool_input": {"command": "rm -rf"}}, self.dir, 1)
        text = (self.dir / "claude-s1.json").read_text()
        self.assertNotIn("SECRET", text); self.assertNotIn("rm -rf", text)
        self.assertEqual(stat.S_IMODE((self.dir / "claude-s1.json").stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.dir.stat().st_mode), 0o700)

    def test_hostile_session_ids_cannot_escape_the_directory(self):
        hook.record("claude", {"session_id": "../../evil", "hook_event_name": "Stop"}, self.dir, 1)
        self.assertEqual([p.name for p in self.dir.iterdir()], ["claude-.._.._evil.json"])


if __name__ == "__main__":
    unittest.main()
