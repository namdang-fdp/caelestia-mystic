import os, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import proc_top as top

CLK = 100


def stat_line(pid, comm, utime=0, stime=0, start=0):
    # Fields after ")" start at field 3 (state); utime=14, stime=15, starttime=22.
    rest = ["S"] + ["0"] * 49
    rest[11] = str(utime)
    rest[12] = str(stime)
    rest[19] = str(start)
    return f"{pid} ({comm}) " + " ".join(rest)


class ProcTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.proc = Path(self.tmp.name)
        (self.proc / "uptime").write_text("1000.00 900.00\n")
        (self.proc / "meminfo").write_text(
            "MemTotal:       16000000 kB\nMemFree: 100 kB\nMemAvailable:    4000000 kB\n"
            "SwapTotal:       8000000 kB\nSwapFree:        6000000 kB\n")
        (self.proc / "stat").write_text("cpu  100 0 100 800 0 0 0 0 0 0\n")

    def tearDown(self):
        self.tmp.cleanup()

    def add(self, pid, comm="proc", rss=None, pss=None, exe=None, cwd=None, utime=0, stime=0, start=0, raw_stat=None):
        d = self.proc / str(pid)
        d.mkdir()
        (d / "stat").write_text(raw_stat or stat_line(pid, comm, utime, stime, start))
        if rss is not None:
            (d / "status").write_text(f"Name:\t{comm}\nVmRSS:\t{rss} kB\n")
        if pss is not None:
            (d / "smaps_rollup").write_text(f"Rss: {rss or pss} kB\nPss:   {pss} kB\n")
        if exe is not None:
            os.symlink(exe, d / "exe")
        if cwd is not None:
            os.symlink(cwd, d / "cwd")
        return d

    def test_meminfo_parses_kb_and_swap(self):
        m = top.read_meminfo(self.proc)
        self.assertEqual(m, {"total_kb": 16000000, "available_kb": 4000000,
                             "swap_total_kb": 8000000, "swap_used_kb": 2000000})

    def test_meminfo_missing_fields_are_zero(self):
        (self.proc / "meminfo").write_text("MemFree: 1 kB\n")
        m = top.read_meminfo(self.proc)
        self.assertEqual((m["total_kb"], m["swap_total_kb"], m["swap_used_kb"]), (0, 0, 0))

    def test_process_fields_from_fake_tree(self):
        self.add(42, "claude", rss=200, pss=150, exe="/opt/app/claude", cwd="/home/u/proj",
                 utime=30, stime=20, start=50000)
        (p,) = top.read_processes(self.proc, clk_tck=CLK)
        self.assertEqual((p["pid"], p["name"], p["exe"], p["cwd"]), (42, "claude", "/opt/app/claude", "/home/u/proj"))
        self.assertEqual((p["rss_kb"], p["pss_kb"], p["ticks"], p["orphan"]), (200, 150, 50, False))
        self.assertAlmostEqual(p["age_s"], 1000 - 500)

    def test_orphan_when_cwd_target_ends_with_deleted(self):
        self.add(7, "claude", rss=10, cwd="/x/y (deleted)")
        (p,) = top.read_processes(self.proc, clk_tck=CLK)
        self.assertTrue(p["orphan"])
        self.assertEqual(p["cwd"], "/x/y")

    def test_stat_comm_with_spaces_and_parens(self):
        self.add(9, "a) b", rss=1, raw_stat=stat_line(9, "a) b", utime=7, stime=3))
        (p,) = top.read_processes(self.proc, clk_tck=CLK)
        self.assertEqual((p["name"], p["ticks"]), ("a) b", 10))

    def test_vanished_pid_is_skipped(self):
        (self.proc / "5").mkdir()
        self.add(6, "ok", rss=1)
        self.assertEqual([p["pid"] for p in top.read_processes(self.proc, clk_tck=CLK)], [6])

    def test_unreadable_exe_falls_back_to_comm_and_rss(self):
        self.add(8, "mystery", rss=321)
        (p,) = top.read_processes(self.proc, clk_tck=CLK)
        self.assertEqual((p["exe"], p["pss_kb"], p["rss_kb"], p["orphan"]), ("", 0, 321, False))
        self.assertEqual(top.group_name(p["exe"], p["name"]), "mystery")

    def test_group_name_map(self):
        cases = {
            ("/opt/zen-browser-bin/zen-bin", "Isolated Web Co"): "Zen",
            ("/home/u/claude-code/2.1/claude", "claude"): "Claude",
            ("/usr/lib/claude-desktop/claude-desktop", "claude-desktop"): "Claude Desktop",
            ("/usr/lib/electron43/electron", "electron"): "Electron",
            ("/home/u/.codex/releases/0.169/codex-app-server", "codex"): "Codex",
            ("/usr/bin/qs", "qs"): "qs",
            ("", "weird"): "weird",
        }
        for (exe, comm), want in cases.items():
            self.assertEqual(top.group_name(exe, comm), want, (exe, comm))

    def test_cpu_percent(self):
        out = top.cpu_percent({1: 0, 2: 10}, {1: 200, 3: 5}, 1.0, 100)
        self.assertEqual(out, {1: 200.0})

    def test_collect_groups_sum_pss_and_lists_claude(self):
        self.add(10, "claude", rss=999, pss=100000, exe="/h/claude-code/claude", cwd="/home/u/a")
        self.add(11, "claude", rss=999, pss=50000, exe="/h/claude-code/claude", cwd="/gone/b (deleted)", start=10000)
        self.add(12, "Isolated Web Co", rss=70000, exe="/opt/zen/zen-bin")
        out = top.collect(self.proc, interval=0, sleep=lambda s: None, clk_tck=CLK)
        self.assertEqual(out["system"]["total_kb"], 16000000)
        self.assertEqual(out["system"]["used_kb"], 12000000)
        self.assertEqual(out["system"]["swap_used_kb"], 2000000)
        groups = {g["name"]: g for g in out["groups"]}
        self.assertEqual((groups["Claude"]["ram_kb"], groups["Claude"]["count"]), (150000, 2))
        self.assertEqual(groups["Zen"]["ram_kb"], 70000)
        claude = sorted(out["claude"], key=lambda c: c["pid"])
        self.assertEqual([c["pid"] for c in claude], [10, 11])
        self.assertEqual([c["orphan"] for c in claude], [False, True])
        self.assertEqual(claude[0]["project"], "a")
        self.assertEqual(claude[1]["ram_kb"], 50000)


if __name__ == "__main__":
    unittest.main()
