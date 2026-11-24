import os, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import shell_setup as setup

ORIGINAL = "export A=1\nalias g=git\n"


class ShellSetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / ".zshrc"
        self.path.write_text(ORIGINAL)
        os.chmod(self.path, 0o640)

    def tearDown(self):
        self.tmp.cleanup()

    def test_install_appends_one_block_keeps_mode_and_backs_up(self):
        setup.install(self.path)
        text = self.path.read_text()
        self.assertTrue(text.startswith(ORIGINAL))
        self.assertEqual(text.count(setup.BEGIN), 1)
        self.assertIn(str(setup.HOOK), text)
        self.assertTrue(setup.status(self.path)["installed"])
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o640)
        self.assertEqual(len(list(Path(self.tmp.name).glob(".zshrc.bak-island-*"))), 1)

    def test_install_twice_does_not_duplicate(self):
        setup.install(self.path); setup.install(self.path)
        self.assertEqual(self.path.read_text().count(setup.BEGIN), 1)

    def test_uninstall_restores_the_original_text_exactly(self):
        setup.install(self.path); setup.uninstall(self.path)
        self.assertEqual(self.path.read_text(), ORIGINAL)
        self.assertFalse(setup.status(self.path)["installed"])

    def test_text_after_the_block_survives_uninstall(self):
        setup.install(self.path)
        with self.path.open("a") as f:
            f.write("export B=2\n")
        setup.uninstall(self.path)
        self.assertEqual(self.path.read_text(), ORIGINAL + "export B=2\n")

    def test_missing_file_is_created_by_install(self):
        path = Path(self.tmp.name) / "new-zshrc"
        setup.install(path)
        self.assertTrue(setup.status(path)["installed"])


if __name__ == "__main__":
    unittest.main()
