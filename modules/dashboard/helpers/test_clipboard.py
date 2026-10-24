import importlib.util
from pathlib import Path
import sys
import subprocess
import os
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('island_clipboard', Path(__file__).with_name('clipboard.py'))
clipboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clipboard)


class ClipboardContractTests(unittest.TestCase):
    def test_list_keeps_ids_and_distinguishes_binary_entries(self):
        rows = clipboard.entries(b'42\ttext with $(literal)\n41\t[[ binary data 12 KiB png 120x80 ]]\nbad row\n')
        self.assertEqual([e['id'] for e in rows], ['42', '41'])
        self.assertFalse(rows[0]['image'])
        self.assertTrue(rows[1]['image'])

    def test_shell_characters_in_text_remain_data(self):
        text = b'$(touch /tmp/unwanted); `id`\nline two'
        with patch.object(sys, 'argv', ['clipboard.py', 'copy', '42']), patch.object(clipboard.shutil, 'which', return_value='/usr/bin/fixture'), patch.object(clipboard, 'run', side_effect=[text, b'']) as run:
            self.assertEqual(clipboard.main(), {'ok': True})
            self.assertEqual(run.call_args_list[0].args, (['cliphist', 'decode'], b'42\t'))
            self.assertEqual(run.call_args_list[1].args, (['wl-copy'], text))

    def test_binary_copy_preserves_bytes(self):
        image = b'\x89PNG\x00\xff\xfe\r\n'
        with patch.object(sys, 'argv', ['clipboard.py', 'copy', '9']), patch.object(clipboard.shutil, 'which', return_value='/usr/bin/fixture'), patch.object(clipboard, 'run', side_effect=[image, b'']) as run:
            clipboard.main()
            self.assertEqual(run.call_args_list[1].args[1], image)

    def test_invalid_id_never_reaches_a_process(self):
        with patch.object(sys, 'argv', ['clipboard.py', 'delete', '4; id']), patch.object(clipboard.shutil, 'which', return_value='/usr/bin/fixture'), patch.object(clipboard, 'run') as run:
            with self.assertRaises(RuntimeError): clipboard.main()
            run.assert_not_called()

    def test_history_is_bounded(self):
        rows = clipboard.entries(b''.join(f'{i}\tentry\n'.encode() for i in range(400)))
        self.assertEqual(len(rows), 200)

    def test_thumbnails_sniff_format_cache_and_reuse(self):
        png = b'\x89PNG\r\n\x1a\n' + b'\x00' * 16
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, {'XDG_CACHE_HOME': folder}):
            with patch.object(clipboard, 'run', return_value=png) as run:
                first = clipboard.thumbnails(['7'])
                second = clipboard.thumbnails(['7'])
            expected = str(Path(folder) / 'caelestia' / 'island-clipboard' / '7.png')
            self.assertEqual(first, {'7': expected})
            self.assertEqual(second, first)
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args, (['cliphist', 'decode'], b'7\t'))
            self.assertEqual(Path(expected).read_bytes(), png)

    def test_thumbnails_skip_non_images_and_failures(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, {'XDG_CACHE_HOME': folder}):
            with patch.object(clipboard, 'run', side_effect=[b'plain text', RuntimeError('boom')]):
                self.assertEqual(clipboard.thumbnails(['1', '2']), {'1': '', '2': ''})
            self.assertEqual(list((Path(folder) / 'caelestia').glob('**/*.*')), [])

    def test_thumbnail_batch_is_bounded(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, {'XDG_CACHE_HOME': folder}):
            with patch.object(clipboard, 'run', return_value=b'GIF89a') as run:
                result = clipboard.thumbnails([str(i) for i in range(40)])
            self.assertEqual(len(result), clipboard.THUMB_BATCH)
            self.assertEqual(run.call_count, clipboard.THUMB_BATCH)

    def test_list_prunes_cache_to_current_ids(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, {'XDG_CACHE_HOME': folder}):
            cache = Path(folder) / 'caelestia' / 'island-clipboard'
            cache.mkdir(parents=True)
            for name in ('42.png', '5.jpg', 'notes.txt', '.tmp-fresh', '.tmp-old'):
                (cache / name).write_bytes(b'x')
            old = time.time() - 600
            os.utime(cache / '.tmp-old', (old, old))
            with patch.object(sys, 'argv', ['clipboard.py', 'list']), patch.object(clipboard.shutil, 'which', return_value='/usr/bin/fixture'), patch.object(clipboard, 'run', return_value=b'42\t[[ binary data 1 KiB png 2x2 ]]\n'):
                clipboard.main()
            self.assertEqual(sorted(p.name for p in cache.iterdir()), ['.tmp-fresh', '42.png', 'notes.txt'])

    def test_delete_removes_cached_thumbnail(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, {'XDG_CACHE_HOME': folder}):
            cache = Path(folder) / 'caelestia' / 'island-clipboard'
            cache.mkdir(parents=True)
            (cache / '9.webp').write_bytes(b'x')
            with patch.object(sys, 'argv', ['clipboard.py', 'delete', '9']), patch.object(clipboard.shutil, 'which', return_value='/usr/bin/fixture'), patch.object(clipboard, 'run', return_value=b''):
                clipboard.main()
            self.assertFalse((cache / '9.webp').exists())

    def test_thumbs_rejects_any_invalid_id(self):
        for argv in (['clipboard.py', 'thumbs'], ['clipboard.py', 'thumbs', '3', '../x'], ['clipboard.py', 'thumbs', '3', '4\n']):
            with patch.object(sys, 'argv', argv), patch.object(clipboard.shutil, 'which', return_value='/usr/bin/fixture'), patch.object(clipboard, 'run') as run:
                with self.assertRaises(RuntimeError): clipboard.main()
                run.assert_not_called()

    def test_image_sniffing(self):
        self.assertEqual(clipboard.image_extension(b'\xff\xd8\xff\xe0'), 'jpg')
        self.assertEqual(clipboard.image_extension(b'RIFF\x00\x00\x00\x00WEBPVP8 '), 'webp')
        self.assertIsNone(clipboard.image_extension(b'<svg>'))

    @unittest.skipUnless(clipboard.shutil.which('cliphist'), 'cliphist is unavailable')
    def test_real_cliphist_id_protocol_copy_and_delete(self):
        with tempfile.TemporaryDirectory() as folder:
            database = str(Path(folder) / 'db')
            fixture = b'Clipboard contract fixture\nLine two'
            subprocess.run(['cliphist', '-db-path', database, 'store'], input=fixture, check=True)
            original_run = clipboard.run
            copied = []
            def isolated_run(args, data=None):
                if args[0] == 'wl-copy': copied.append(data); return b''
                return original_run([args[0], '-db-path', database, *args[1:]], data)
            with patch.object(clipboard, 'run', side_effect=isolated_run), patch.dict(os.environ, {'XDG_CACHE_HOME': folder}):
                key = clipboard.entries(isolated_run(['cliphist', 'list']))[0]['id']
                with patch.object(sys, 'argv', ['clipboard.py', 'copy', key]): clipboard.main()
                self.assertEqual(copied, [fixture])
                with patch.object(sys, 'argv', ['clipboard.py', 'delete', key]): clipboard.main()
                self.assertEqual(isolated_run(['cliphist', 'list']), b'')


if __name__ == '__main__': unittest.main()
