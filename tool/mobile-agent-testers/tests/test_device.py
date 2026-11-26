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
  'shell getprop sys.boot_completed') echo 1 ;;
  'shell pidof system_server') [[ -f restarted ]] && echo 321 || echo 123 ;;
  'shell pm path android') echo package:/system/framework/framework-res.apk ;;
  'shell service check settings') echo 'Service settings: found' ;;
  'shell service check uimode')
    if [[ -f restarted && ! -f ui-ready ]]; then touch ui-ready; echo 'Service uimode: not found'
    else echo 'Service uimode: found'; fi ;;
  'shell am get-started-user-state 0')
    if [[ -f restarted && ! -f unlocked ]]; then touch unlocked; echo RUNNING_LOCKED
    else echo RUNNING_UNLOCKED; fi ;;
  'shell getprop persist.sys.locale') [[ $CASE == reconnect && ! -f restarted ]] && echo en-US || echo zh-TW ;;
  root) touch rooting ;;
  unroot) touch unrooting ;;
  'shell id -u')
    if [[ -f unrooting ]]; then rm unrooting rooting root-ready; echo 0
    elif [[ -f root-ready ]]; then echo 0
    elif [[ -f rooting ]]; then touch root-ready; exit 1  # transport not yet reconnected
    else echo 2000; fi ;;
  'shell setprop persist.sys.locale zh-TW') [[ -f root-ready ]] ;;
  'shell setprop ctl.restart zygote') touch restarted ;;
  'shell settings put system font_scale 1.3'|'shell cmd uimode night yes') ;;
  'shell settings get system font_scale') echo 1.3 ;;
  'shell cmd uimode night') echo 'Night mode: yes' ;;
  'emu geo fix 121.517 25.0478') echo OK ;;
  'shell pm list packages qa.app') [[ $CASE != stale ]] || echo package:qa.app ;;
  'install app.apk') [[ $CASE != install ]] ;;
  'shell pm path qa.app') echo package:/data/app/qa.app/base.apk ;;
  'shell sha256sum /data/app/qa.app/base.apk')
    if [[ $CASE == mismatch ]]; then echo wrong; else sha256sum app.apk; fi ;;
  'shell cmd package resolve-activity --brief '*'-p qa.app')
    if [[ $CASE == reconnect && ! -f published ]]; then touch published; echo 'No activity found'
    else echo qa.app/.Main; fi ;;
  'shell am start -W '*'-n qa.app/.Main')
    if [[ $CASE == launch ]]; then echo 'Error: Activity not started'
    elif [[ $CASE == cold-* ]]; then echo 'Status: timeout'
    else echo 'Status: ok'; fi ;;
  'shell dumpsys window displays')
    if [[ $CASE == cold-unfocused ]]; then echo 'mCurrentFocus=Window{ace u0 other.app/.Main}'
    else echo 'mCurrentFocus=Window{abc u0 qa.app/qa.app.Main}'; fi ;;
  'shell dumpsys window windows')
    echo '  Window #0 Window{abc u0 qa.app/qa.app.Main}:'
    if [[ $CASE != cold-pending ]]; then echo '    mDrawState=HAS_DRAWN mLastHidden=false'
    else echo '    mDrawState=DRAW_PENDING'; fi
    echo '    isVisible=true'
    echo '  Window #1 Window{def u0 Splash Screen qa.app/qa.app.Main}:'
    echo '    mDrawState=HAS_DRAWN mLastHidden=false'; echo '    isVisible=true' ;;
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
            for scenario, failure in [('pass', None), ('stale', 'fresh-install-check'), ('install', 'install-apk'),
                                      ('mismatch', 'verify-installed-apk'), ('launch', 'start-activity'),
                                      ('cold-drawn', None), ('cold-unfocused', 'first-frame'),
                                      ('cold-pending', 'first-frame'), ('reconnect', None)]:
                with self.subTest(scenario=scenario):
                    (root / 'calls').write_text('')
                    env = dict(PATH=f'{root}:/usr/bin:/bin', CASE=scenario, FONT_SCALE='1.3', THEME='dark',
                               GEO='25.0478,121.517', LOCALE='zh-TW', APP_ID='ignored.wrong')
                    proc = subprocess.run(['bash', '-euc', 'set -o pipefail; source "$1"; '
                                           'sleep() { SECONDS=$((SECONDS + 2)); }; '  # advance bounded waits
                                           'prepare_device >/dev/null 2>&1 || { echo "$stage"; exit 1; }; '
                                           '[[ $APP_ID == qa.app && $LAUNCH_COMPONENT == qa.app/.Main ]]',
                                           'test', str(DEVICE)], cwd=root, env=env, capture_output=True, text=True, timeout=15)
                    self.assertEqual(proc.returncode == 0, failure is None, proc.stdout + proc.stderr)
                    if failure:
                        self.assertEqual(proc.stdout.strip(), 'device-setup/' + failure)
                    if scenario == 'reconnect':
                        self.assertTrue((root / 'ui-ready').exists())
                        self.assertTrue((root / 'unlocked').exists())
                        self.assertTrue((root / 'published').exists())
                        self.assertFalse((root / 'root-ready').exists(), 'must restore shell UID before install')
                    calls = (root / 'calls').read_text().splitlines()
                    self.assertEqual([c for c in calls if c.startswith('install ')],
                                     [] if scenario == 'stale' else ['install app.apk'])
                    starts = [c for c in calls if c.startswith('shell am start ')]
                    self.assertEqual(len(starts), int(scenario not in ('stale', 'install', 'mismatch')))
                    self.assertEqual('shell dumpsys window displays' in calls, scenario.startswith('cold-'))
                    self.assertFalse(any(' grant ' in c for c in calls))
