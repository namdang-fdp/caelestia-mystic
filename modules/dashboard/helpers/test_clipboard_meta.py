import os, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import clipboard_meta as meta


class MetaTests(unittest.TestCase):
    def test_expiry_only_touches_old_tagged_entries_that_still_exist(self):
        data = {"1": {"app": "a", "t": 0}, "2": {"app": "b", "t": 9000}, "3": {"app": "c", "t": 0}}
        self.assertEqual(sorted(meta.expired(data, 10000, 1, {"1", "2"})), ["1"])
        self.assertEqual(meta.expired(data, 10000, 0, {"1"}), [])

    def test_missing_entries_are_forgotten(self):
        self.assertEqual(meta.forget_missing({"1": {}, "2": {}}, {"2"}), {"2": {}})

    def test_app_names_are_sanitised(self):
        self.assertEqual(meta.clean_app("org.kde.dolphin"), "org.kde.dolphin")
        self.assertEqual(meta.clean_app("a$(rm -rf)b\n"), "arm -rfb")
        self.assertEqual(len(meta.clean_app("x" * 200)), 48)

    def test_listing_ids(self):
        self.assertEqual(meta.present_ids("12\thello\n7\tx\nbad\tline\n"), ["12", "7"])

    def test_save_is_private_and_roundtrips(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "m.json"
            meta.save({"1": {"app": "x", "t": 1}}, path)
            self.assertEqual(meta.load(path), {"1": {"app": "x", "t": 1}})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_wipe_clears_history_and_saved_details(self):
        from unittest.mock import patch
        import subprocess
        with tempfile.TemporaryDirectory() as d, patch.dict(os.environ, {"XDG_STATE_HOME": d}):
            meta.save({"1": {"app": "x", "t": 1}})
            calls = []
            def fake(*args, data=None):
                calls.append(args)
                out = b"1\ttext\n" if args[0] == "list" else b""
                return subprocess.CompletedProcess(args, 0, stdout=out, stderr=b"")
            with patch.object(meta, "cliphist", side_effect=fake):
                result = meta.main(["x", "wipe"])
            self.assertEqual(result, {"ok": True, "removed": 1})
            self.assertIn(("wipe",), calls)
            self.assertEqual(meta.load(), {})

    def test_failed_wipe_is_an_error_and_keeps_details(self):
        from unittest.mock import patch
        import subprocess
        with tempfile.TemporaryDirectory() as d, patch.dict(os.environ, {"XDG_STATE_HOME": d}):
            meta.save({"1": {"app": "x", "t": 1}})
            def fake(*args, data=None):
                return subprocess.CompletedProcess(args, 1 if args[0] == "wipe" else 0, stdout=b"1\tt\n", stderr=b"")
            with patch.object(meta, "cliphist", side_effect=fake):
                with self.assertRaises(RuntimeError):
                    meta.main(["x", "wipe"])
            self.assertIn("1", meta.load())


if __name__ == "__main__":
    unittest.main()
