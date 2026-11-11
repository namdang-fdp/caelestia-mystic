import json, os, sys, tempfile, unittest
from datetime import datetime, timezone
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import agent_stats as stats

NOW = datetime(2026, 11, 10, 12, 0, tzinfo=timezone.utc).timestamp()


def iso(offset_seconds):
    return datetime.fromtimestamp(NOW + offset_seconds, timezone.utc).isoformat().replace("+00:00", "Z")


def claude_row(offset, mid, i=10, o=5, c=0):
    return {"type": "assistant", "timestamp": iso(offset), "requestId": "r" + mid,
            "message": {"id": mid, "usage": {"input_tokens": i, "output_tokens": o, "cache_creation_input_tokens": c, "cache_read_input_tokens": 999}}}


class StatsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, rows):
        path = self.home / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
        os.utime(path, (NOW, NOW))

    def test_claude_dedupes_streamed_messages_and_skips_cache_reads(self):
        self.write(".claude/projects/p/a.jsonl", [claude_row(-60, "m1"), claude_row(-60, "m1"), claude_row(-30, "m2", 1, 1, 8)])
        out = stats.collect(self.home, NOW)["providers"]["claude"]
        self.assertEqual((out["today"]["calls"], out["today"]["tokens"]), (2, 15 + 10))
        self.assertTrue(out["fiveHour"]["active"])
        self.assertEqual(out["fiveHour"]["resetsAt"], NOW - 60 + 5 * 3600)

    def test_window_restarts_after_five_hours(self):
        self.write(".claude/projects/p/a.jsonl", [claude_row(-9 * 3600, "m1"), claude_row(-100, "m2")])
        w = stats.collect(self.home, NOW)["providers"]["claude"]["fiveHour"]
        self.assertEqual(w["calls"], 1)
        self.write(".claude/projects/p/a.jsonl", [claude_row(-6 * 3600, "m1")])
        self.assertFalse(stats.collect(self.home, NOW)["providers"]["claude"]["fiveHour"]["active"])

    def test_codex_counts_uncached_input_plus_output(self):
        row = {"timestamp": iso(-10), "type": "event_msg", "payload": {"type": "token_count", "info": {"last_token_usage": {"input_tokens": 100, "cached_input_tokens": 60, "output_tokens": 7}}}}
        null = {"timestamp": iso(-5), "type": "event_msg", "payload": {"type": "token_count", "info": None}}
        self.write(".codex/sessions/2026/11/10/r.jsonl", [row, null])
        out = stats.collect(self.home, NOW)["providers"]["codex"]
        self.assertEqual((out["today"]["calls"], out["today"]["tokens"]), (1, 47))

    def test_missing_logs_and_week_shape(self):
        out = stats.collect(self.home, NOW)["providers"]
        self.assertFalse(out["claude"]["available"])
        self.assertEqual(len(out["codex"]["week"]), 7)
        self.assertEqual(out["codex"]["week"][-1]["date"], datetime.fromtimestamp(NOW).date().isoformat())

    def test_garbage_lines_do_not_break_parsing(self):
        path = self.home / ".claude/projects/p/a.jsonl"
        path.parent.mkdir(parents=True)
        path.write_text('not json "usage" "assistant"\n' + json.dumps(claude_row(-5, "m1")) + "\n")
        os.utime(path, (NOW, NOW))
        self.assertEqual(stats.collect(self.home, NOW)["providers"]["claude"]["today"]["calls"], 1)


if __name__ == "__main__":
    unittest.main()
