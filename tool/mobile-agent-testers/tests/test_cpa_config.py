"""Offline policy tests shared by the probe and Claude launcher."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'runtime' / 'scripts'))
from cpa_config import validate_config


class CPAConfigTests(unittest.TestCase):
    def test_sdk_supplies_exactly_one_v1(self):
        for root in ('https://cpa.invalid', 'https://cpa.invalid:8443/a/b', 'https://[::1]:8443', 'https://v1'):
            for suffix in ('', '/', '/v1', '/v1/'):
                with self.subTest(root=root, suffix=suffix):
                    self.assertEqual(validate_config(root + suffix, 'tenant/example(high)', 'key'), root)

    def test_wrong_endpoint_never_receives_a_key(self):
        for url in ('', 'http://localhost', 'ftp://cpa.invalid', 'https://', 'https://cpa.invalid:65536',
                    'https://cpa.invalid:0', 'https://cpa.invalid:', 'https://bad..invalid', 'https://[::1]extra',
                    'https://[v1.example]ignored/', 'https://[v1.host]/v1',
                    'https://a@cpa.invalid', 'https://cpa.invalid?', 'https://cpa.invalid#',
                    'https://cpa.invalid\\@api.anthropic.com', 'https://cpa.invalid/../a',
                    'https://cpa.invalid/a%2fb', 'https://cpa.invalid/v1/messages', 'https://cpa.invalid//v1',
                    'https://api.ANTHROPIC.com.:443/prefix', 'https://claude.ai', 'https://cpa.invalid\n'):
            with self.subTest(url=url), self.assertRaises(ValueError):
                validate_config(url, 'test-model', 'key')

    def test_no_alias_or_empty_auth(self):
        for model, key in (('OPUS', 'k'), ('opusplan', 'k'), ('sonnet[1m]', 'k'), ('', 'k'),
                           ('model', ''), ('model', ' \n'), ('model', 'secret\nheader')):
            with self.subTest(model=model), self.assertRaises(ValueError):
                validate_config('https://cpa.invalid', model, key)


if __name__ == '__main__':
    unittest.main()
