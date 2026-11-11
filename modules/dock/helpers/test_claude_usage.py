import importlib.util
import io
import json
import tempfile
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('dock_claude_usage', Path(__file__).with_name('claude_usage.py'))
claude = importlib.util.module_from_spec(spec)
spec.loader.exec_module(claude)

USAGE = {'five_hour': {'utilization': 12, 'resets_at': None}}
FRESH = lambda token: {'accessToken': token, 'expiresAt': (time.time() + 3600) * 1000}
STALE = lambda token: {'accessToken': token, 'expiresAt': (time.time() - 10) * 1000}


def http_error(code):
    return urllib.error.HTTPError(claude.USAGE_URL, code, 'error', {}, io.BytesIO(b''))


class CollectTests(unittest.TestCase):
    def run_collect(self, credentials, fetch):
        """credentials: list of oauth dicts returned by successive reads (last one repeats)."""
        reads = list(credentials)
        read = lambda: reads.pop(0) if len(reads) > 1 else reads[0]
        with patch.object(claude, 'read_oauth', side_effect=read) as reader, \
                patch.object(claude, 'fetch', side_effect=fetch) as fetched, \
                patch('subprocess.run') as spawned:
            try:
                result = claude.collect()
            except claude.UsageError as exc:
                result = str(exc)
            # Claude must never be started from here: that races Claude Code's own refresh.
            self.assertEqual(spawned.call_count, 0)
            return result, reader.call_count, fetched.call_count

    def test_valid_token_is_used_as_is(self):
        result, reads, fetches = self.run_collect([FRESH('a')], [USAGE])
        self.assertTrue(result['available'])
        self.assertEqual((reads, fetches), (1, 1))

    def test_expired_token_picks_up_one_refreshed_by_claude_code(self):
        result, reads, fetches = self.run_collect([STALE('a'), FRESH('b')], [USAGE])
        self.assertTrue(result['available'])
        self.assertEqual((reads, fetches), (2, 1))

    def test_expired_token_that_stays_expired_reports_expiry_without_fetching(self):
        result, reads, fetches = self.run_collect([STALE('a')], [USAGE])
        self.assertEqual((result, reads, fetches), (claude.EXPIRED_MESSAGE, 2, 0))

    def test_credentials_cleared_meanwhile_reports_expiry(self):
        def read():
            if read.calls:
                raise claude.UsageError('Sign in to Claude Code to see usage')
            read.calls += 1
            return STALE('a')
        read.calls = 0
        with patch.object(claude, 'read_oauth', side_effect=read), patch.object(claude, 'fetch') as fetched:
            with self.assertRaises(claude.AuthError):
                claude.collect()
        self.assertEqual(fetched.call_count, 0)

    def test_401_rereads_once_and_retries_with_a_new_token(self):
        result, reads, fetches = self.run_collect([FRESH('a'), FRESH('b')], [http_error(401), USAGE])
        self.assertTrue(result['available'])
        self.assertEqual((reads, fetches), (2, 2))

    def test_401_with_an_unchanged_token_is_not_retried(self):
        result, reads, fetches = self.run_collect([FRESH('a')], [http_error(401), USAGE])
        self.assertEqual((result, reads, fetches), (claude.EXPIRED_MESSAGE, 2, 1))

    def test_retry_errors_keep_their_messages(self):
        cases = [(http_error(500), 'Claude usage request failed (500)'),
                 (urllib.error.URLError('down'), 'Unable to reach Claude'),
                 (ValueError('bad json'), 'Claude returned an invalid usage response')]
        for error, message in cases:
            with self.subTest(message=message):
                result, reads, fetches = self.run_collect([FRESH('a'), FRESH('b')], [http_error(401), error])
                self.assertEqual((result, reads, fetches), (message, 2, 2))


class InstallTests(unittest.TestCase):
    def test_missing_claude_code_is_flagged(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(claude.os.environ, {'CLAUDE_CONFIG_DIR': tmp}), \
                patch.object(claude, 'find_claude', return_value=None), patch('builtins.print') as out:
            claude.main()
        output = json.loads(out.call_args.args[0])
        self.assertEqual((output['available'], output['installed'], output['error']), (False, False, 'Claude Code is not installed'))

    def test_signed_out_claude_code_is_installed(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(claude.os.environ, {'CLAUDE_CONFIG_DIR': tmp}), \
                patch.object(claude, 'find_claude', return_value='/usr/bin/claude'), patch('builtins.print') as out:
            claude.main()
        output = json.loads(out.call_args.args[0])
        self.assertEqual((output['installed'], output['error']), (True, 'Sign in to Claude Code to see usage'))


class RedirectTests(unittest.TestCase):
    def test_authorization_is_not_redirected(self):
        captured = {}

        def fake_open(opener, request, timeout):
            captured['handlers'] = [type(h) for h in opener.handlers]
            captured['request'] = request
            raise urllib.error.URLError('offline')

        with patch.object(urllib.request.OpenerDirector, 'open', fake_open):
            with self.assertRaises(urllib.error.URLError):
                claude.fetch('secret-token')
        request = captured['request']
        self.assertIn(claude.NoRedirect, captured['handlers'])
        self.assertNotIn('Authorization', request.headers)
        self.assertEqual(request.unredirected_hdrs.get('Authorization'), 'Bearer secret-token')

    def test_redirects_are_refused(self):
        handler = claude.NoRedirect()
        self.assertIsNone(handler.redirect_request(None, None, 302, 'Found', {}, 'https://example.com'))


if __name__ == '__main__':
    unittest.main()
