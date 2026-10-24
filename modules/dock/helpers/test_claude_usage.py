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
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        patcher = patch.dict(claude.os.environ, {'XDG_STATE_HOME': self.tmp.name})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self.tmp.cleanup)

    def run_collect(self, credentials, fetch):
        """credentials: list of oauth dicts returned by successive reads (last one repeats)."""
        reads = list(credentials)
        read = lambda: reads.pop(0) if len(reads) > 1 else reads[0]
        with patch.object(claude, 'read_oauth', side_effect=read), \
                patch.object(claude, 'run_auth_status') as auth, \
                patch.object(claude, 'fetch', side_effect=fetch) as fetched:
            try:
                return claude.collect(), auth.call_count, fetched.call_count
            except claude.UsageError as exc:
                return str(exc), auth.call_count, fetched.call_count

    def test_valid_token_does_not_refresh(self):
        result, auths, fetches = self.run_collect([FRESH('a')], [USAGE])
        self.assertTrue(result['available'])
        self.assertEqual((auths, fetches), (0, 1))

    def test_expired_token_refreshes_once_then_fetches(self):
        result, auths, fetches = self.run_collect([STALE('a'), FRESH('b')], [USAGE])
        self.assertTrue(result['available'])
        self.assertEqual((auths, fetches), (1, 1))

    def test_401_refreshes_at_most_once(self):
        result, auths, fetches = self.run_collect([FRESH('a'), FRESH('b')], [http_error(401), http_error(401)])
        self.assertEqual(result, claude.EXPIRED_MESSAGE)
        self.assertEqual((auths, fetches), (1, 2))

    def test_failed_refresh_backs_off_on_next_run(self):
        result, auths, _ = self.run_collect([STALE('a')], [USAGE])
        self.assertEqual((result, auths), (claude.EXPIRED_MESSAGE, 1))
        self.assertTrue(claude.state_file().exists())
        result, auths, fetches = self.run_collect([STALE('a')], [USAGE])
        self.assertEqual((result, auths, fetches), (claude.EXPIRED_MESSAGE, 0, 0))

    def test_backoff_expires(self):
        self.run_collect([STALE('a')], [USAGE])
        with patch.object(claude, 'last_refresh_failure', return_value=time.time() - claude.REFRESH_BACKOFF_SECONDS - 1):
            _, auths, _ = self.run_collect([STALE('a'), FRESH('b')], [USAGE])
        self.assertEqual(auths, 1)

    def test_successful_fetch_clears_backoff(self):
        self.run_collect([STALE('a')], [USAGE])
        self.run_collect([FRESH('new')], [USAGE])
        self.assertFalse(claude.state_file().exists())

    def test_retry_errors_keep_their_messages(self):
        cases = [(http_error(500), 'Claude usage request failed (500)'),
                 (urllib.error.URLError('down'), 'Unable to reach Claude'),
                 (ValueError('bad json'), 'Claude returned an invalid usage response')]
        for error, message in cases:
            with self.subTest(message=message):
                claude.record_refresh_failure(False)
                result, auths, fetches = self.run_collect([FRESH('a'), FRESH('b')], [http_error(401), error])
                self.assertEqual((result, auths, fetches), (message, 1, 2))

    def test_unchanged_token_after_refresh_is_not_retried(self):
        result, auths, fetches = self.run_collect([FRESH('a')], [http_error(401), USAGE])
        self.assertEqual((result, auths, fetches), (claude.EXPIRED_MESSAGE, 1, 1))


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
