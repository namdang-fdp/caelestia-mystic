import importlib.util
import json
import os
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('dock_codex_usage', Path(__file__).with_name('codex_usage.py'))
codex = importlib.util.module_from_spec(spec)
spec.loader.exec_module(codex)


def pipe_with(*chunks: bytes, close: bool = True) -> int:
    read_fd, write_fd = os.pipe()
    for chunk in chunks:
        os.write(write_fd, chunk)
    if close:
        os.close(write_fd)
    return read_fd


class ReadResponseTests(unittest.TestCase):
    def test_lines_arriving_in_one_chunk_are_all_seen(self):
        init = json.dumps({'id': 1, 'result': {}})
        limits = json.dumps({'id': 2, 'result': {'rateLimits': {'planType': 'plus'}}})
        # Keep the writer open so a missed line would block until the timeout
        fd = pipe_with(f'{init}\n{limits}\n'.encode(), close=False)
        start = time.monotonic()
        self.assertEqual(codex.read_response(fd, 2, 3), {'rateLimits': {'planType': 'plus'}})
        self.assertLess(time.monotonic() - start, 1)

    def test_message_split_across_reads(self):
        read_fd, write_fd = os.pipe()
        line = json.dumps({'id': 2, 'result': {'ok': True}}).encode() + b'\n'

        def writer():
            os.write(write_fd, line[:10])
            time.sleep(0.05)
            os.write(write_fd, line[10:])

        threading.Thread(target=writer).start()
        self.assertEqual(codex.read_response(read_fd, 2, 3), {'ok': True})
        os.close(write_fd)

    def test_noise_and_other_ids_are_skipped(self):
        fd = pipe_with(b'not json\n[]\n{"method":"x"}\n{"id":2,"result":{"a":1}}\n')
        self.assertEqual(codex.read_response(fd, 2, 3), {'a': 1})

    def test_eof_before_response(self):
        fd = pipe_with(b'{"id":1,"result":{}}\n')
        with self.assertRaisesRegex(codex.UsageError, 'exited'):
            codex.read_response(fd, 2, 3)

    def test_timeout(self):
        fd = pipe_with(close=False)
        with self.assertRaisesRegex(codex.UsageError, 'timed out'):
            codex.read_response(fd, 2, 0.1)


class ErrorMappingTests(unittest.TestCase):
    def test_auth_errors_ask_to_sign_in(self):
        for message in ('Not logged in', 'authentication required', 'Unauthorized', 'Please login first'):
            self.assertEqual(codex.rpc_error({'code': -32600, 'message': message}), 'Sign in to Codex to see usage')

    def test_other_errors_are_reported(self):
        self.assertEqual(codex.rpc_error({'code': -32601, 'message': 'Method not found'}), 'Codex usage request failed: Method not found')
        self.assertEqual(codex.rpc_error(None), 'Codex usage request failed')

    def test_rpc_error_response_is_mapped(self):
        fd = pipe_with(b'{"id":2,"error":{"code":-32601,"message":"Method not found"}}\n')
        with self.assertRaisesRegex(codex.UsageError, 'Method not found'):
            codex.read_response(fd, 2, 3)


class FindCodexTests(unittest.TestCase):
    def test_chatgpt_bundled_cli_is_a_candidate(self):
        self.assertIn(Path('/usr/lib/chatgpt/resources/codex'), codex.codex_candidates())

    def test_path_lookup_wins(self):
        with patch.object(codex.shutil, 'which', return_value='/opt/bin/codex'):
            self.assertEqual(codex.find_codex(), '/opt/bin/codex')

    def test_missing_cli_reports_not_installed(self):
        with patch.object(codex, 'find_codex', return_value=None):
            with self.assertRaisesRegex(codex.NotInstalled, 'not installed'):
                codex.request_rate_limits()

    def test_main_flags_missing_cli(self):
        with patch.object(codex, 'find_codex', return_value=None), patch('builtins.print') as out:
            codex.main()
        output = json.loads(out.call_args.args[0])
        self.assertEqual((output['available'], output['installed']), (False, False))

    def test_main_flags_other_errors_as_installed(self):
        with patch.object(codex, 'request_rate_limits', side_effect=codex.UsageError('Sign in to Codex to see usage')), patch('builtins.print') as out:
            codex.main()
        self.assertTrue(json.loads(out.call_args.args[0])['installed'])


if __name__ == '__main__':
    unittest.main()
