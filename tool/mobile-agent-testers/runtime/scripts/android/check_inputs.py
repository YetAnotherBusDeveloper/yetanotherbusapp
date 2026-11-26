"""Validate workflow inputs before touching the emulator. Never log input values."""
import json
import math
import os
from pathlib import Path
import re
import sys


def regular(path):
    return not path.is_symlink() and path.is_file() and path.stat().st_size > 0


def valid(env):
    persona = env['PERSONA']
    brief = Path(env['BRIEF'])
    if not (re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,63}', persona)
            and (env['BRIEF'] == 'AGENT_BRIEF.md' or re.fullmatch(
                r'briefs/[A-Za-z0-9_-][A-Za-z0-9_.-]*\.md', env['BRIEF']))
            and not Path('briefs').is_symlink()
            and all(regular(p) for p in (brief, Path('app.apk'), Path('personas.json')))):
        return False
    personas = json.loads(Path('personas.json').read_text(encoding='utf-8'))
    if not isinstance(personas, list):
        return False
    matches = [p for p in personas if isinstance(p, dict) and p.get('id') == persona]
    if len(matches) != 1 or matches[0].get('platform', 'android') != 'android':
        return False
    device = env['DEVICE']
    if not (0 < len(device) <= 256 and device.isprintable() and device.strip()
            and re.fullmatch(r'[a-zA-Z]{2,3}(?:-[a-zA-Z0-9]{2,8})*', env['LOCALE'])
            and env['THEME'] in ('light', 'dark')
            and env['RECORD_VIDEO'] in ('true', 'false')
            and re.fullmatch(r'[1-9][0-9]?', env['MAX_ACTIONS'])
            and int(env['MAX_ACTIONS']) <= 40
            and re.fullmatch(r'[0-9]+(?:\.[0-9]+)?', env['FONT_SCALE'])
            and math.isfinite(float(env['FONT_SCALE'])) and float(env['FONT_SCALE']) > 0):
        return False
    coord = r'-?[0-9]+(?:\.[0-9]+)?'
    if not re.fullmatch(fr'{coord},{coord}', env['GEO']):
        return False
    lat, lon = map(float, env['GEO'].split(','))
    return -90 <= lat <= 90 and -180 <= lon <= 180


if __name__ == '__main__':
    try:
        sys.exit(0 if valid(os.environ) else 1)
    except (OSError, KeyError, ValueError):
        sys.exit(1)
