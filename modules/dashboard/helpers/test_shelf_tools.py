import os, sys, tempfile, unittest, zipfile
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import shelf_tools as tools
from PIL import Image


class ShelfToolsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        os.environ["XDG_DOWNLOAD_DIR"] = str(self.dir / "out")
        self.png = self.dir / "a.png"
        Image.new("RGBA", (400, 200), (255, 0, 0, 128)).save(self.png)
        self.jpg = self.dir / "b.jpg"
        Image.new("RGB", (100, 300), "blue").save(self.jpg)
        self.text = self.dir / "note.txt"
        self.text.write_text("hi")

    def tearDown(self):
        self.tmp.cleanup()

    def test_zip_keeps_originals_and_nested_folders(self):
        folder = self.dir / "docs"; (folder / "sub").mkdir(parents=True)
        (folder / "sub" / "x.txt").write_text("x")
        out = tools.main(["t", "zip", str(self.text), str(folder)])
        names = zipfile.ZipFile(out["outputs"][0]).namelist()
        self.assertIn("note.txt", names); self.assertIn("docs/sub/x.txt", names)
        self.assertTrue(self.text.exists())

    def test_convert_never_overwrites_and_flattens_transparency_for_jpeg(self):
        out = tools.main(["t", "convert", "jpg", str(self.png)])
        result = Path(out["outputs"][0])
        self.assertEqual(result.name, "a.jpg")
        self.assertEqual(Image.open(result).mode, "RGB")
        again = tools.main(["t", "convert", "jpg", str(self.png)])
        self.assertEqual(Path(again["outputs"][0]).name, "a (1).jpg")
        self.assertTrue(self.png.exists())

    def test_non_images_are_skipped_and_all_skipped_is_an_error(self):
        out = tools.main(["t", "convert", "png", str(self.jpg), str(self.text)])
        self.assertEqual((len(out["outputs"]), out["skipped"]), (1, 1))
        with self.assertRaises(RuntimeError):
            tools.main(["t", "convert", "png", str(self.text)])

    def test_resize_keeps_aspect_ratio(self):
        out = tools.main(["t", "resize", "150", str(self.png)])
        self.assertEqual(Image.open(out["outputs"][0]).size, (150, 75))
        self.assertEqual(Path(out["outputs"][0]).name, "a-150.png")

    def test_pdf_has_one_page_per_image(self):
        out = tools.main(["t", "pdf", str(self.png), str(self.jpg), str(self.text)])
        data = Path(out["outputs"][0]).read_bytes()
        self.assertTrue(data.startswith(b"%PDF"))
        self.assertEqual(data.count(b"/Type /Page\n") + data.count(b"/Type /Page "), data.count(b"/Type /Page") - data.count(b"/Type /Pages"))
        self.assertEqual(out["skipped"], 1)

    def test_relative_and_missing_paths_are_ignored(self):
        with self.assertRaises(RuntimeError):
            tools.main(["t", "zip", "relative.txt", str(self.dir / "missing")])


if __name__ == "__main__":
    unittest.main()
