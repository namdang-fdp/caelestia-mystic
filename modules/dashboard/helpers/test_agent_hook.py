import json, os, stat, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import agent_hook as hook


class AgentHookTests(unittest.TestCase):
    def test_codex_approval_is_observed_and_cleared_after_tool_use(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            request = {"session_id": "test", "hook_event_name": "PermissionRequest", "tool_name": "Bash"}
            hook.record("codex", request, state, now=1)
            path = state / "codex-test.json"
            record = json.loads(path.read_text())
            self.assertEqual(record["state"], "waiting")
            self.assertFalse(record["decidable"])
            hook.record("codex", {"session_id": "test", "hook_event_name": "PostToolUse"}, state, now=2)
            self.assertFalse(path.exists())
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

    def test_permission_request_stores_tool_detail_and_a_request_id(self):
        payload = {"session_id": "s1", "cwd": "/home/u/proj", "hook_event_name": "PermissionRequest",
                   "tool_name": "Bash", "tool_use_id": "toolu_1", "tool_input": {"command": "npm   test\n--watch"}}
        hook.record("claude", payload, self.dir, 100, pid=4242)
        data = self.read("claude-s1.json")
        self.assertEqual((data["tool"], data["detail"], data["request"], data["decidable"]), ("Bash", "npm test --watch", "toolu_1", True))
        self.assertEqual((data["pid"], data["cwd"]), (4242, "/home/u/proj"))

    def test_questions_are_not_decidable(self):
        hook.record("claude", {"session_id": "s1", "hook_event_name": "PermissionRequest", "tool_name": "AskUserQuestion", "tool_input": {}}, self.dir, 1)
        self.assertFalse(self.read("claude-s1.json")["decidable"])

    def test_notification_after_a_request_keeps_its_detail_and_later_states_drop_it(self):
        base = {"session_id": "s1", "cwd": "/p"}
        hook.record("claude", {**base, "hook_event_name": "PermissionRequest", "tool_name": "Bash", "tool_use_id": "t1", "tool_input": {"command": "ls"}}, self.dir, 1)
        hook.record("claude", {**base, "hook_event_name": "Notification", "notification_type": "permission_prompt"}, self.dir, 2)
        data = self.read("claude-s1.json")
        self.assertEqual((data["request"], data["detail"]), ("t1", "ls"))
        hook.record("claude", {**base, "hook_event_name": "PostToolUse"}, self.dir, 3)
        data = self.read("claude-s1.json")
        self.assertNotIn("detail", data); self.assertNotIn("request", data)
        self.assertEqual(data["cwd"], "/p")

    def test_decision_is_only_taken_for_the_matching_request(self):
        hook.record("claude", {"session_id": "s1", "hook_event_name": "PermissionRequest", "tool_name": "Bash", "tool_use_id": "t2", "tool_input": {"command": "rm x"}}, self.dir, 1)
        path = hook.decision_path(self.dir, "claude", "s1")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"request": "stale", "behavior": "allow"}))
        clock = iter(range(0, 1000)).__next__
        slept = []
        def sleeper(_):
            slept.append(1)
            if len(slept) == 3:  # the island answers the right request on the third poll
                path.write_text(json.dumps({"request": "t2", "behavior": "deny"}))
        got = hook.wait_for_decision(self.dir, "claude", "s1", "t2", limit=50, sleep=sleeper, clock=clock)
        self.assertEqual(got, "deny")
        self.assertFalse(path.exists())

    def test_waiting_stops_when_the_prompt_is_answered_elsewhere(self):
        hook.record("claude", {"session_id": "s1", "hook_event_name": "PermissionRequest", "tool_name": "Bash", "tool_use_id": "t3", "tool_input": {}}, self.dir, 1)
        calls = []
        def sleeper(_):
            calls.append(1)
            hook.record("claude", {"session_id": "s1", "hook_event_name": "PostToolUse"}, self.dir, 2)
        got = hook.wait_for_decision(self.dir, "claude", "s1", "t3", limit=50, sleep=sleeper, clock=iter(range(100)).__next__)
        self.assertIsNone(got); self.assertEqual(len(calls), 1)

    def test_waiting_gives_up_at_the_limit_and_ignores_bad_behaviors(self):
        hook.record("claude", {"session_id": "s1", "hook_event_name": "PermissionRequest", "tool_name": "Bash", "tool_use_id": "t4", "tool_input": {}}, self.dir, 1)
        path = hook.decision_path(self.dir, "claude", "s1"); path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"request": "t4", "behavior": "always"}))
        got = hook.wait_for_decision(self.dir, "claude", "s1", "t4", limit=5, sleep=lambda _: None, clock=iter(range(100)).__next__)
        self.assertIsNone(got)

    def test_output_shape_matches_claude_codes_contract(self):
        allow = json.loads(hook.decision_output("allow"))["hookSpecificOutput"]
        self.assertEqual(allow, {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}})
        self.assertEqual(json.loads(hook.decision_output("deny"))["hookSpecificOutput"]["decision"]["behavior"], "deny")

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
