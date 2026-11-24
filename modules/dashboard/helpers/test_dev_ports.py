import os, signal, sys, tempfile, unittest
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0, os.path.dirname(__file__))
import dev_ports as ports

SS = """LISTEN 0 511 127.0.0.1:3000 0.0.0.0:* users:(("node",pid=1234,fd=20))
LISTEN 0 511 [::1]:3000 [::]:* users:(("node",pid=1234,fd=21))
LISTEN 0 4096 0.0.0.0:5432 0.0.0.0:*
LISTEN 0 128 *:8080 *:* users:(("java",pid=77,fd=5))
LISTEN 0 4096 [::]:22 [::]:*
garbage line
"""


class ParseTests(unittest.TestCase):
    def test_parse_groups_by_port_and_reads_scope_and_owner(self):
        got = {p["port"]: p for p in ports.parse_ss(SS)}
        self.assertEqual(sorted(got), [22, 3000, 5432, 8080])
        self.assertEqual((got[3000]["scope"], got[3000]["name"], got[3000]["pid"]), ("local", "node", 1234))
        self.assertEqual((got[5432]["scope"], got[5432]["pid"]), ("all", 0))
        self.assertEqual(got[8080]["scope"], "all")


class ListingTests(unittest.TestCase):
    def test_only_your_own_dev_processes_are_listed(self):
        ss = SS + 'LISTEN 0 1 127.0.0.1:34563 0.0.0.0:* users:(("claude",pid=55,fd=3))\n'
        run = lambda *a, **k: SimpleNamespace(stdout=ss, returncode=0 if a[0][0] == "ss" else 1)
        got = ports.listing(run)
        self.assertEqual([p["port"] for p in got["ports"]], [3000, 8080])
        self.assertEqual(got["containers"], [])


class ActionTests(unittest.TestCase):
    def test_kill_refuses_processes_that_are_not_listening_or_not_yours(self):
        run = lambda *a, **k: SimpleNamespace(stdout=SS, returncode=0)
        sent = []
        with tempfile.TemporaryDirectory() as t:
            proc = Path(t)
            for pid, uid in ((1234, os.getuid()), (77, os.getuid() + 1)):
                (proc / str(pid)).mkdir()
                (proc / str(pid) / "status").write_text(f"Name:\tx\nUid:\t{uid}\t{uid}\t{uid}\t{uid}\n")
            self.assertEqual(ports.kill(1234, run=run, sender=lambda p, s: sent.append((p, s)), proc=proc), {"ok": True})
            self.assertEqual(sent, [(1234, signal.SIGTERM)])
            for pid in (77, 4242, 1):
                self.assertIn("error", ports.kill(pid, run=run, sender=lambda *a: sent.append(a), proc=proc))
            self.assertEqual(len(sent), 1)

    def test_docker_is_optional_and_stop_only_touches_running_containers(self):
        no_docker = lambda *a, **k: (_ for _ in ()).throw(FileNotFoundError())
        self.assertEqual(ports.containers(no_docker), [])
        row = '{"Names":"db","Image":"postgres","Ports":"5432/tcp","Status":"Up 2 hours"}'
        calls = []
        def run(args, **k):
            calls.append(args)
            return SimpleNamespace(stdout=row + "\n", returncode=0)
        self.assertEqual(ports.stop("db", run=run), {"ok": True})
        self.assertIn(["docker", "stop", "db"], calls)
        for bad in ("web", "--all", "db; rm -rf /", ""):
            self.assertIn("error", ports.stop(bad, run=run))

    def test_describe_shortens_the_command_and_names_the_project(self):
        with tempfile.TemporaryDirectory() as t:
            proc = Path(t); d = proc / "9"; d.mkdir()
            (d / "cmdline").write_bytes(b"/usr/bin/node\x00server.js\x00--port\x00300\x00extra\x00")
            os.symlink(t, d / "cwd")
            got = ports.describe(9, proc)
            self.assertEqual(got["cmd"], "node server.js --port 300")
            self.assertEqual(got["project"], Path(t).name)


if __name__ == "__main__":
    unittest.main()
