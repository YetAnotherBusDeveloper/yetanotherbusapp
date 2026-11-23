"""Verify the real setup script against a deterministic Android shell, no SDK needed."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

DEVICE = Path(__file__).resolve().parents[1] / 'runtime/scripts/android/device.sh'
ADB = '''#!/usr/bin/env bash
[[ $1 != -s ]] || shift 2
printf '%s\\n' "$*" >> calls
case "$*" in
  'wait-for-device') ;;
  'get-serialno') echo emulator-5554 ;;
  'shell getprop ro.kernel.qemu'|'shell getprop sys.boot_completed'|'shell pidof system_server') echo 1 ;;
  'shell pm path android') echo package:/system/framework/framework-res.apk ;;
  'shell getprop persist.sys.locale') echo zh-TW ;;
  'shell id -u') echo 2000 ;;
  'shell settings put system font_scale 1.3'|'shell cmd uimode night yes') ;;
  'shell settings get system font_scale') echo 1.3 ;;
  'shell cmd uimode night') echo 'Night mode: yes' ;;
  'emu geo fix 121.517 25.0478') echo OK ;;
  'shell pm list packages qa.app') [[ $CASE != stale ]] || echo package:qa.app ;;
  'install app.apk') [[ $CASE != install ]] ;;
  'shell pm path qa.app') echo package:/data/app/qa.app/base.apk ;;
  'shell sha256sum /data/app/qa.app/base.apk')
    if [[ $CASE == mismatch ]]; then echo wrong; else sha256sum app.apk; fi ;;
  'shell cmd package resolve-activity --brief '*'-p qa.app') echo qa.app/.Main ;;
  'shell am start -W '*'-n qa.app/.Main')
    if [[ $CASE == launch ]]; then echo 'Error: Activity not started'; else echo 'Status: ok'; fi ;;
  *) exit 2 ;;
esac
'''


@unittest.skipUnless(sys.platform.startswith('linux'), 'Linux runner')
class DeviceTests(unittest.TestCase):
    def test_fresh_install_and_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'app.apk').write_bytes(b'fixture, not a real APK')
            for name, script in [('adb', ADB), ('aapt2', '#!/bin/sh\n[ "$*" = "dump packagename app.apk" ] && echo qa.app\n')]:
                (root / name).write_text(script)
                (root / name).chmod(0o700)
            for scenario in ('pass', 'stale', 'install', 'mismatch', 'launch'):
                with self.subTest(scenario=scenario):
                    (root / 'calls').write_text('')
                    env = dict(PATH=f'{root}:/usr/bin:/bin', CASE=scenario, FONT_SCALE='1.3', THEME='dark',
                               GEO='25.0478,121.517', LOCALE='zh-TW', APP_ID='ignored.wrong')
                    proc = subprocess.run(['bash', '-euc', 'set -o pipefail; source "$1"; prepare_device; '
                                           '[[ $APP_ID == qa.app && $LAUNCH_COMPONENT == qa.app/.Main ]]',
                                           'test', str(DEVICE)], cwd=root, env=env, capture_output=True, timeout=15)
                    self.assertEqual(proc.returncode == 0, scenario == 'pass', proc.stderr)
                    calls = (root / 'calls').read_text().splitlines()
                    self.assertEqual([c for c in calls if c.startswith('install ')],
                                     [] if scenario == 'stale' else ['install app.apk'])
                    self.assertEqual(any(c.startswith('shell am start ') for c in calls), scenario in ('pass', 'launch'))
                    self.assertFalse(any(' grant ' in c for c in calls))
