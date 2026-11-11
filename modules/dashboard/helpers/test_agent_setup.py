import json, os, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import agent_setup as setup


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "settings.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_install_preserves_existing_settings_and_hooks_and_backs_up(self):
        original = {"model": "sonnet", "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "notify-send done"}]}]}}
        self.path.write_text(json.dumps(original))
        setup.install(self.path)
        data = json.loads(self.path.read_text())
        self.assertEqual(data["model"], "sonnet")
        self.assertEqual(len(data["hooks"]["Stop"]), 2)
        self.assertEqual(data["hooks"]["Stop"][0], original["hooks"]["Stop"][0])
        self.assertTrue(setup.status(self.path)["claude"])
        self.assertEqual(len(list(Path(self.tmp.name).glob("settings.json.bak-island-*"))), 1)

    def test_install_twice_does_not_duplicate(self):
        self.path.write_text("{}")
        setup.install(self.path); setup.install(self.path)
        data = json.loads(self.path.read_text())
        self.assertTrue(all(len(v) == 1 for v in data["hooks"].values()))

    def test_uninstall_restores_other_hooks_exactly(self):
        original = {"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "notify-send done"}]}]}}
        self.path.write_text(json.dumps(original))
        setup.install(self.path); setup.uninstall(self.path)
        self.assertEqual(json.loads(self.path.read_text()), original)
        self.assertFalse(setup.status(self.path)["claude"])

    def test_invalid_settings_are_left_untouched(self):
        self.path.write_text("{not json")
        with self.assertRaises(ValueError):
            setup.install(self.path)
        self.assertEqual(self.path.read_text(), "{not json")


if __name__ == "__main__":
    unittest.main()


class GeminiTests(unittest.TestCase):
    def test_gemini_events_and_agent_name(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "settings.json"
            path.write_text("{}")
            setup.install(path, setup.GEMINI_EVENTS, "gemini")
            data = json.loads(path.read_text())
            self.assertEqual(sorted(data["hooks"]), sorted(setup.GEMINI_EVENTS))
            self.assertTrue(data["hooks"]["BeforeTool"][0]["hooks"][0]["command"].endswith("agent_hook.py gemini"))
            self.assertTrue(setup.status(path, setup.GEMINI_EVENTS)["installed"])
            self.assertFalse(setup.status(path)["installed"])
