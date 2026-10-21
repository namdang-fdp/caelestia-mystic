import importlib.util
from pathlib import Path
import sys
import subprocess
import tempfile
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
            with patch.object(clipboard, 'run', side_effect=isolated_run):
                key = clipboard.entries(isolated_run(['cliphist', 'list']))[0]['id']
                with patch.object(sys, 'argv', ['clipboard.py', 'copy', key]): clipboard.main()
                self.assertEqual(copied, [fixture])
                with patch.object(sys, 'argv', ['clipboard.py', 'delete', key]): clipboard.main()
                self.assertEqual(isolated_run(['cliphist', 'list']), b'')


if __name__ == '__main__': unittest.main()
