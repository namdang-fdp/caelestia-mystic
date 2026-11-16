import os, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import sys_stats as ss


class SysStatsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.sys, self.proc = base / "sys", base / "proc"
        (self.sys / "class/drm").mkdir(parents=True)
        self.proc.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def card(self, name, cur=None, mx=None):
        d = self.sys / "class/drm" / name
        d.mkdir()
        if cur is not None:
            (d / "gt_cur_freq_mhz").write_text(f"{cur}\n")
        if mx is not None:
            (d / "gt_max_freq_mhz").write_text(f"{mx}\n")

    def diskstats(self, read_sectors, write_sectors, name="nvme0n1"):
        (self.proc / "diskstats").write_text(
            f"   7 0 loop0 1 0 2 0 0 0 0 0 0 0 0\n 259 0 {name} 10 0 {read_sectors} 5 20 0 {write_sectors} 7 0 0 0\n")

    def mounts(self, source="/dev/nvme0n1p2"):
        (self.proc / "mounts").write_text(f"{source} / btrfs rw 0 0\ntmpfs /tmp tmpfs rw 0 0\n")

    def test_gpu_clock_from_first_card_with_freq_files(self):
        self.card("card0")
        self.card("card1", cur=800, mx=2250)
        self.card("card1-eDP-1", cur=1, mx=1)
        self.assertEqual(ss.read_gpu(self.sys), {"cur_mhz": 800, "max_mhz": 2250})

    def test_gpu_none_without_freq_files(self):
        self.card("card0")
        self.assertIsNone(ss.read_gpu(self.sys))
        self.assertIsNone(ss.read_gpu(self.sys / "missing"))

    def test_whole_disk_name(self):
        for part, whole in {"nvme0n1p2": "nvme0n1", "sda3": "sda", "mmcblk0p1": "mmcblk0", "vda": "vda", "dm-0": "dm-0"}.items():
            self.assertEqual(ss.whole_disk(part), whole, part)

    def test_disk_throughput_from_two_diskstats_samples(self):
        self.mounts()
        self.diskstats(1000, 4000)
        def advance(_seconds):
            self.diskstats(1000 + 400, 4000 + 1000)
        out = ss.collect(self.sys, self.proc, root=self.tmp.name, interval=2.0, sleep=advance)
        self.assertEqual(out["disk"]["read_bps"], 400 * 512 / 2.0)
        self.assertEqual(out["disk"]["write_bps"], 1000 * 512 / 2.0)

    def test_missing_diskstats_gives_zero_rates(self):
        out = ss.collect(self.sys, self.proc, root=self.tmp.name, interval=0.1, sleep=lambda s: None)
        self.assertEqual((out["disk"]["read_bps"], out["disk"]["write_bps"]), (0, 0))

    def test_usage_comes_from_statvfs_and_is_consistent(self):
        out = ss.collect(self.sys, self.proc, root=self.tmp.name, interval=0.1, sleep=lambda s: None)
        d = out["disk"]
        self.assertGreater(d["total_kb"], 0)
        self.assertTrue(0 <= d["used_kb"] <= d["total_kb"])
        self.assertIsNone(out["gpu"])


if __name__ == "__main__":
    unittest.main()
