import json, os, stat, sys, tempfile, unittest
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0, os.path.dirname(__file__))
import agent_action as action
import agent_hook as hook


def fake_proc(root: Path, tree: dict, cwds: dict = None, cmdlines: dict = None):
    """tree: pid -> ppid. Builds a minimal /proc."""
    for pid, ppid in tree.items():
        d = root / str(pid); d.mkdir(parents=True)
        (d / "stat").write_text(f"{pid} (weird) name) S {ppid} 0 0")
        (d / "cmdline").write_bytes(b"\0".join((cmdlines or {}).get(pid, [b"zsh"])) + b"\0")
        if cwds and pid in cwds:
            os.symlink(cwds[pid], d / "cwd")


class DecisionTests(unittest.TestCase):
    def test_decision_files_are_private_and_validated(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t) / "agents"
            p = action.write_decision(d, "claude", "s1", "req", "allow")
            self.assertEqual(json.loads(p.read_text()), {"request": "req", "behavior": "allow"})
            self.assertEqual(stat.S_IMODE(p.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(p.parent.stat().st_mode), 0o700)
            for bad in (("claude", "s1", "", "allow"), ("claude", "s1", "req", "always")):
                with self.assertRaises(ValueError):
                    action.write_decision(d, *bad)

    def test_hook_accepts_the_islands_decision_file(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            hook.record("claude", {"session_id": "s", "hook_event_name": "PermissionRequest", "tool_name": "Bash", "tool_use_id": "r1", "tool_input": {"command": "x"}}, d, 1)
            action.write_decision(d, "claude", "s", "r1", "allow")
            self.assertEqual(hook.wait_for_decision(d, "claude", "s", "r1", limit=3, sleep=lambda _: None, clock=iter(range(9)).__next__), "allow")


class FocusTests(unittest.TestCase):
    def test_parent_pid_survives_parentheses_in_the_command_name(self):
        with tempfile.TemporaryDirectory() as t:
            fake_proc(Path(t), {10: 5, 5: 1})
            self.assertEqual(action.parent_pid(10, Path(t)), 5)
            self.assertEqual(action.parent_pid(999, Path(t)), 0)

    def test_window_is_found_through_the_process_ancestry(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            fake_proc(root, {300: 200, 200: 100, 100: 50, 50: 1})
            clients = [{"pid": 77, "address": "0x1"}, {"pid": 100, "address": "0xabc"}]
            self.assertEqual(action.client_for(300, clients, root)["address"], "0xabc")
            self.assertIsNone(action.client_for(300, [{"pid": 7, "address": "0x1"}], root))

    def test_codex_is_found_by_cwd_and_app_server_is_skipped(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t) / "proc"; root.mkdir()
            cwd = Path(t) / "proj"; cwd.mkdir()
            fake_proc(root, {11: 1, 12: 1, 13: 1}, cwds={11: cwd, 12: cwd, 13: Path(t)},
                      cmdlines={11: [b"/usr/bin/codex", b"app-server", b"--stdio"], 12: [b"/home/u/.local/bin/codex"], 13: [b"codex"]})
            self.assertEqual(action.find_agent_pid("codex", str(cwd), root), 12)
            self.assertEqual(action.find_agent_pid("claude", str(cwd), root), 0)
            self.assertEqual(action.find_agent_pid("codex", "", root), 0)

    def test_focus_dispatches_to_the_clients_address_only(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t); fake_proc(root, {300: 100, 100: 1})
            calls = []
            def run(args, **kw):
                calls.append(args)
                return SimpleNamespace(stdout=json.dumps([{"pid": 100, "address": "0xdead"}]))
            self.assertEqual(action.focus("claude", 300, "/p", run=run, proc=root), {"ok": True})
            self.assertIn("address:0xdead", calls[-1][-1])
            bad = lambda args, **kw: SimpleNamespace(stdout=json.dumps([{"pid": 100, "address": "0x1\" }) evil(\""}]))
            self.assertIn("error", action.focus("claude", 300, "/p", run=bad, proc=root))

    def test_ambiguous_codex_terminals_use_the_thread_link(self):
        with tempfile.TemporaryDirectory() as t:
            proc = Path(t) / "proc"
            fake_proc(proc, {12: 1, 13: 1}, cwds={12: t, 13: t},
                      cmdlines={12: [b"codex"], 13: [b"codex"]})
            session = "07dd125e-0699-449c-83ed-9c1694854bfe"
            calls = []
            def run(args, **kwargs):
                calls.append(args)
                return SimpleNamespace(stdout="chatgpt.desktop\n", returncode=0)
            self.assertEqual(action.focus("codex", 0, t, run=run, proc=proc, session=session), {"ok": True})
            self.assertEqual(calls[-1], ["gio", "open", f"codex://threads/{session}"])


if __name__ == "__main__":
    unittest.main()
