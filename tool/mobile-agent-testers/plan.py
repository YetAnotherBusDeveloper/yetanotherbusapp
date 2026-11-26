"""Resolve trusted YABus source and a small Android matrix before spending tokens."""
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent


def git(*args):
    return subprocess.run(['git', *args], capture_output=True, text=True, check=True).stdout.strip()


def source_sha(ref, dispatch_sha):
    # Only literal in-repo branches, tags or full SHAs, never revision expressions,
    # fork URLs, pull refs, or commits outside the dispatch commit's history.
    if not ref:
        candidate = dispatch_sha
    elif re.fullmatch('[0-9a-fA-F]{40}', ref):
        candidate = ref
    else:
        name = ref.removeprefix('refs/heads/').removeprefix('refs/tags/')
        if (not re.fullmatch(r'[\w./-]+', name, re.ASCII) or name.startswith('-') or
                (ref.startswith('refs/') and not ref.startswith(('refs/tags/', 'refs/heads/')))):
            raise ValueError('Use a branch, tag or full commit SHA, not a pull ref or expression.')
        git('check-ref-format', 'refs/heads/' + name)
        refs = (['refs/remotes/origin/' + name] if not ref.startswith('refs/tags/') else []) + (
            ['refs/tags/' + name] if not ref.startswith('refs/heads/') else [])
        matches = [r for r in refs if subprocess.run(['git', 'show-ref', '--verify', '--quiet', r]).returncode == 0]
        if len(matches) != 1:
            raise ValueError('Unknown or ambiguous ref; use a full SHA or qualified branch/tag.')
        candidate = matches[0]
    sha = git('rev-parse', '--verify', candidate + '^{commit}')
    if subprocess.run(['git', 'merge-base', '--is-ancestor', sha, dispatch_sha]).returncode:
        raise ValueError('The app ref must already be in trusted default-branch history.')
    return sha


def matrix(personas, actions, brief):
    if not re.fullmatch(r'[1-9][0-9]?', actions) or int(actions) > 40:
        raise ValueError('Choose an integer action limit from 1 to 40.')
    if brief not in ('yabus', 'search') or not (ROOT / 'runtime/briefs' / (brief + '.md')).is_file():
        raise ValueError('Unknown YABus brief.')
    ids = [s.strip() for s in personas.split(',')]
    known = {p['id']: p for p in json.loads((ROOT / 'runtime/personas.json').read_text(encoding='utf-8'))}
    if not (1 <= len(ids) <= 3 and len(set(ids)) == len(ids) and all(i in known for i in ids)):
        raise ValueError('Choose 1 to 3 distinct Android persona IDs from runtime/personas.json.')
    rows = []
    for persona in ids:
        p = known[persona]
        d = p['device']
        rows.append(dict(persona=persona, device=d['name'], profile=d['profile'], api=d['android_api'],
                         font_scale=d['font_scale'], theme=d['theme'], locale=p['locale'], geo=','.join(map(str, p['geo']))))
    return rows


if __name__ == '__main__':
    try:
        rows = matrix(os.environ['PERSONAS'], os.environ['MAX_ACTIONS'], os.environ['BRIEF'])
        sha = source_sha(os.environ['APP_REF'], os.environ['GITHUB_SHA'])
    except (ValueError, subprocess.CalledProcessError) as exc:
        raise SystemExit(str(exc) if isinstance(exc, ValueError) else 'Could not resolve a trusted app ref.') from None
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as out:
        print('sha=' + sha, 'matrix=' + json.dumps(rows), sep='\n', file=out)
    print(f'Building {sha}; {len(rows)} Android tester(s), one at a time.')
