"""Budgeted Android UI commands. This is the only agent-permitted input tool."""
import fcntl
import os
from pathlib import Path
import re
import subprocess
import sys

import type as text_input


def adb(*args):
    subprocess.run(['adb', 'shell', *args], check=True, timeout=45,
                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def command(args):
    op, *rest = args
    if op == 'back' and not rest:
        return lambda: adb('input', 'keyevent', 'KEYCODE_BACK')
    if ((op == 'tap' and len(rest) == 2 or op == 'swipe' and len(rest) in (4, 5))
            and all(re.fullmatch(r'[0-9]{1,5}', n) for n in rest)
            and (len(rest) != 5 or 1 <= int(rest[4]) <= 3000)):
        return lambda: adb('input', op, *rest)
    if op == 'type' and len(rest) == 1:
        return lambda: text_input.main(rest)
    if op == 'relaunch' and not rest:
        # Never resolve a caller-supplied package/activity or reset app storage.
        package, component = os.environ['APP_ID'], os.environ['LAUNCH_COMPONENT']
        if (not re.fullmatch(r'[A-Za-z][A-Za-z0-9_.]+', package) or
                not re.fullmatch(re.escape(package) + r'/[A-Za-z0-9_.]+', component)):
            raise ValueError
        def relaunch():
            adb('am', 'force-stop', package)
            adb('am', 'start', '-W', '-n', component)
        return relaunch
    raise ValueError


def main(args):
    act = command(args)
    limit = int(os.environ['MAX_ACTIONS'])
    if not 1 <= limit <= 40:
        raise ValueError
    # Serialize concurrent calls and charge BEFORE adb: a timed-out gesture
    # might still reach the phone. Append one byte; an interrupted write cannot
    # truncate/reset the counter. The runner creates the private state directory.
    with (Path(os.environ['AGENT_STATE_DIR']) / 'ui-actions').open('ab') as state:
        fcntl.flock(state, fcntl.LOCK_EX)
        if os.fstat(state.fileno()).st_size >= limit:
            sys.exit('UI action budget exhausted; write the final report.')
        state.write(b'+')
        state.flush()
        act()


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except (ValueError, KeyError, OSError, subprocess.SubprocessError):
        sys.exit('Invalid or failed Android action. Inspect the screen before retrying.')
