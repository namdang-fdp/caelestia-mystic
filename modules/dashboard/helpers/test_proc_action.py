import json, os, signal, subprocess, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import proc_action as act

HERE = Path(__file__).resolve().parent


def stat_line(pid, comm, start):
    rest = ["S"] + ["0"] * 49
    rest[19] = str(start)
    return f"{pid} ({comm}) " + " ".join(rest)


class StopTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.proc = Path(self.tmp.name)
        self.calls = []

    def tearDown(self):
        self.tmp.cleanup()

    def add(self, pid, comm="app", start=500, exe=None):
        d = self.proc / str(pid)
        d.mkdir()
        (d / "stat").write_text(stat_line(pid, comm, start))
        if exe:
            os.symlink(exe, d / "exe")

    def stop(self, pid, start=500, uid=None, self_pids=()):
        return act.stop(pid, start, proc=self.proc, uid=os.getuid() if uid is None else uid,
                        kill=lambda p, s: self.calls.append((p, s)), self_pids=self_pids)

    def test_stop_sends_sigterm_once_for_own_matching_process(self):
        self.add(70)
        self.assertEqual(self.stop(70), {"ok": True, "error": ""})
        self.assertEqual(self.calls, [(70, signal.SIGTERM)])

    def test_refuses_when_start_ticks_differ(self):
        self.add(70, start=500)
        self.assertEqual(self.stop(70, start=501), {"ok": False, "error": "changed"})
        self.assertEqual(self.calls, [])

    def test_refuses_other_users_process(self):
        self.add(70)
        self.assertEqual(self.stop(70, uid=os.getuid() + 1), {"ok": False, "error": "not yours"})
        self.assertEqual(self.calls, [])

    def test_refuses_protected_names(self):
        for i, name in enumerate(sorted(act.PROTECTED)):
            self.add(100 + i, comm=name)
            self.assertEqual(self.stop(100 + i)["error"], "protected", name)
        self.add(200, comm="renamed", exe="/usr/bin/qs")
        self.assertEqual(self.stop(200)["error"], "protected")
        self.assertEqual(self.calls, [])

    def test_refuses_pid_1_and_below(self):
        for pid in (1, 0, -5):
            if pid > 0:
                self.add(pid)
            self.assertEqual(self.stop(pid)["error"], "system", pid)
        self.assertEqual(self.calls, [])

    def test_refuses_own_and_parent_pid(self):
        self.add(70)
        self.add(71)
        self.assertEqual(self.stop(70, self_pids=(70, 71))["error"], "system")
        self.assertEqual(self.stop(71, self_pids=(70, 71))["error"], "system")
        self.assertEqual(self.calls, [])

    def test_missing_pid_reports_gone(self):
        self.assertEqual(self.stop(999), {"ok": False, "error": "gone"})

    def test_process_that_vanishes_before_the_signal_reports_gone(self):
        self.add(70)
        def vanish(pid, sig):
            raise ProcessLookupError
        out = act.stop(70, 500, proc=self.proc, uid=os.getuid(), kill=vanish, self_pids=())
        self.assertEqual(out, {"ok": False, "error": "gone"})

    def test_cli_prints_json_and_bad_args_fail_cleanly(self):
        bad = subprocess.run([sys.executable, "-I", str(HERE / "proc_action.py"), "stop", "abc", "1"],
                             capture_output=True, text=True)
        self.assertEqual(bad.returncode, 2)
        self.assertEqual(json.loads(bad.stdout), {"ok": False, "error": "usage"})
        gone = subprocess.run([sys.executable, "-I", str(HERE / "proc_action.py"), "stop", "999999999", "1"],
                              capture_output=True, text=True)
        self.assertEqual(gone.returncode, 1)
        self.assertEqual(json.loads(gone.stdout), {"ok": False, "error": "gone"})


if __name__ == "__main__":
    unittest.main()
