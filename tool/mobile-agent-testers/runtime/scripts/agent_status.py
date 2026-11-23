"""Report only a fixed status for `claude -p --output-format json` (never model text).

Adapted from mobile-agent-testers/scripts/agent_status.py (MIT). Unlike upstream,
missing/malformed results and turn exhaustion must fail the job.
"""
import json
from pathlib import Path
import re
import sys


FAILURES = (
    ('auth', r'authentication_error|invalid (?:api key|bearer token)|api error: 40[13]|not logged in'),
    ('quota', r'credit balance|insufficient[_ ](?:credit|balance|quota)|billing|usage limit'),
    ('rate_limit', r'rate_limit_error|rate limit|api error: 429|too many requests'),
    ('overloaded', r'overloaded|api error: 529'),
)


def diagnose(response, errors, cli_failed):
    # Bound diagnostics: a malformed response is not a reason to load an entire
    # transcript into memory. Oversized, partial or unparseable JSON cannot pass.
    with response.open('rb') as stream:
        raw = stream.read(4 * 1024 * 1024 + 1)
    try:
        data = json.loads(raw) if len(raw) <= 4 * 1024 * 1024 else None
    except (UnicodeError, ValueError, RecursionError):
        data = None
    if isinstance(data, list):  # older CLI versions can emit an array of messages
        data = data[-1] if data else None
    result = data if isinstance(data, dict) and data.get('type') == 'result' else {}
    if result.get('subtype') == 'error_max_turns':
        return 'max_turns'
    if (not cli_failed and result.get('subtype') == 'success' and result.get('is_error') is False
            and result.get('stop_reason') in (None, 'end_turn', 'stop_sequence')):
        return 'finished'
    with errors.open('rb') as stream:
        err = stream.read(64 * 1024).decode('utf-8', errors='replace')
    details = [result.get('result'), result.get('error')]
    if isinstance(result.get('errors'), list):
        details.extend(result['errors'])
    message = '\n'.join([err, *(s for s in details if isinstance(s, str))])
    for label, pattern in FAILURES:
        if re.search(pattern, message, re.I):
            return label
    return 'cli_error' if cli_failed else 'invalid_response'


if __name__ == '__main__':
    try:
        status = diagnose(Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]) != 0)
    except (OSError, ValueError, IndexError, RecursionError):
        status = 'invalid_response'
    # Exclusive creation: do not follow a stale symlink or reuse a previous status.
    try:
        with Path(sys.argv[4]).open('x', encoding='ascii') as target:
            target.write(status + '\n')
    except (IndexError, OSError):
        sys.exit(1)
    sys.exit(0 if status == 'finished' else 1)
