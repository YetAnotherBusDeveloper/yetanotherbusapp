"""Offline contract checks: workflow_dispatch -> trusted ref -> encrypted artifact."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import plan


class Dispatch(unittest.TestCase):
    def test_workflow(self):
        # BaseLoader avoids YAML 1.1 interpreting the GitHub 'on' key as True.
        text = (ROOT.parents[1] / '.github/workflows/mobile-agent-testers.yml').read_text(encoding='utf-8')
        w = yaml.load(text, Loader=yaml.BaseLoader)
        self.assertEqual(list(w['on']), ['workflow_dispatch'])
        defaults = {k: v.get('default', '') for k, v in w['on']['workflow_dispatch']['inputs'].items()}
        self.assertEqual(defaults, dict(android_personas='anna', ref='', brief='yabus', max_actions='15', record_video='false'))
        self.assertEqual(w['permissions'], {'contents': 'read'})
        self.assertEqual(set(re.findall(r'secrets\.(\w+)', text)), {'LLM_API_KEY', 'LLM_BASE_URL', 'LLM_MODEL'})
        self.assertEqual(w['jobs']['test']['strategy']['max-parallel'], '1')
        uploads = []
        for job in w['jobs'].values():
            for step in job['steps']:
                if 'uses' in step:
                    self.assertRegex(step['uses'], r'@[0-9a-f]{40}$')
                if step.get('uses', '').startswith('actions/upload-artifact@'):
                    uploads.append(step)
        self.assertEqual(len(uploads), 1)
        self.assertEqual(uploads[0]['with']['path'].splitlines(), [
            '${{ runner.temp }}/yabus-ciphertext/${{ matrix.persona }}.' + suffix for suffix in ['key.bin', 'tgz.enc']])
        self.assertIn("steps.encrypt.outcome == 'success'", uploads[0]['if'])
        self.assertNotIn('demo-app', text)

    def test_plan(self):
        self.assertEqual([r['persona'] for r in plan.matrix('anna', '15', 'yabus')], ['anna'])
        self.assertEqual([r['persona'] for r in plan.matrix('anna, malik', '40', 'search')], ['anna', 'malik'])
        for args in [('anna', '0', 'yabus'), ('anna', '41', 'yabus'), ('anna', '1', '../test'),
                     ('all', '1', 'yabus'), ('clara', '1', 'search'), ('anna,anna', '20', 'search'),
                     ('malik,anna,grace,olga', '1', 'yabus')]:
            with self.subTest(args=args), self.assertRaises(ValueError):
                plan.matrix(*args)

    def test_ref_trust_boundary(self):
        with tempfile.TemporaryDirectory() as tmp:
            def git(*args):
                return subprocess.check_output(['git', '-C', tmp, *args], text=True).strip()
            git('init', '-q', '-b', 'main')
            def commit():
                git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false',
                    'commit', '--allow-empty', '-qm', 'fixture')
                return git('rev-parse', 'HEAD')
            parent = commit()
            git('update-ref', 'refs/tags/release-test', parent)
            dispatch = commit()
            git('update-ref', 'refs/remotes/origin/main', dispatch)
            future = commit()
            prev = os.getcwd()
            try:
                os.chdir(tmp)
                for ref, want in [('', dispatch), ('main', dispatch), ('refs/tags/release-test', parent), (parent, parent)]:
                    self.assertEqual(plan.source_sha(ref, dispatch), want)
                for ref in [future, 'refs/pull/1/head', 'HEAD~1', '-h', 'refs/heads/missing']:
                    with self.subTest(ref=ref), self.assertRaises(ValueError):
                        plan.source_sha(ref, dispatch)
            finally:
                os.chdir(prev)


@unittest.skipUnless(os.name == 'posix', 'Bash/OpenSSL pipeline runs on Linux')
class Artifact(unittest.TestCase):
    def test_round_trip_and_wrong_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            def run(*args, check=True):
                return subprocess.run(args, cwd=tmp, check=check, capture_output=True)
            for key in ['recipient', 'other']:
                run('openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', key)
            run('openssl', 'pkey', '-in', 'recipient', '-pubout', '-out', 'pub')
            results = tmp / 'results/anna'
            results.mkdir(parents=True)
            (results / 'report.md').write_text('private fixture')
            (results / '01.png').write_bytes(b'example image bytes')
            run('bash', ROOT/'encrypt.sh', '.', 'anna', 'pub', 'cipher')
            self.assertEqual(sorted(p.name for p in (tmp/'cipher').iterdir()), ['anna.key.bin', 'anna.tgz.enc'])
            self.assertNotIn(b'private fixture', (tmp/'cipher/anna.tgz.enc').read_bytes())
            self.assertNotEqual(run('bash', ROOT/'decrypt.sh', 'other', 'cipher/anna.key.bin', 'wrong', check=False).returncode, 0)
            run('bash', ROOT/'decrypt.sh', 'recipient', 'cipher/anna.key.bin', 'recovered')
            for p in results.iterdir():
                self.assertEqual((tmp/'recovered/results/anna'/p.name).read_bytes(), p.read_bytes())
            (results/'bad').symlink_to(tmp/'other')
            self.assertNotEqual(run('bash', ROOT/'encrypt.sh', '.', 'anna', 'pub', 'bad', check=False).returncode, 0)


if __name__ == '__main__':
    unittest.main()
