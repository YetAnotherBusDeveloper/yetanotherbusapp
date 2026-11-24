"""Report only a fixed status for `claude -p --output-format json` (never model text).

Adapted from mobile-agent-testers/scripts/agent_status.py (MIT). Unlike upstream,
missing/malformed results and turn exhaustion must fail the job.
"""
import json
from pathlib import Path
import re
import sys


MAX_RESPONSE = 4 * 1024 * 1024
MAX_STDERR = 64 * 1024

# Hints, not validation. Only fixed labels, never a match or an input field,
# can leave the private session directory.
FAILURES = (
    ('auth', r'authentication_error|permission_error|invalid (?:api key|x-api-key|bearer token)|'
             r'(?:api error:|http) 40[13]\b|not logged in'),
    ('quota', r'credit balance|insufficient[_ ](?:credit|balance|quota)|billing|usage limit'),
    ('rate_limit', r'rate_limit_error|rate limit|(?:api error:|http) 429\b|too many requests'),
    ('overloaded', r'overloaded|(?:api error:|http) 529\b'),
    ('model_or_endpoint', r'model[_ ]not[_ ]found|unknown model|issue with the selected model|'
                          r'not_found_error|(?:api error:|http) 404\b'),
    ('invalid_request', r'invalid_request_error|context_length_exceeded|prompt is too long|'
                        r'(?:api error:|http) (?:400|413|422)\b'),
    ('provider_error', r'internal_server_error|(?:api error:|http) 5\d\d\b'),
    ('connection', r'\b(?:ENOTFOUND|EAI_AGAIN|ECONNREFUSED|ECONNRESET|ETIMEDOUT)\b|'
                   r'connection error|fetch failed|request timed out|certificate verify failed'),
    ('cli_arguments', r'(?:unknown|unrecognized|unsupported|invalid) (?:option|flag|argument)|'
                      r'option [^\n]{1,120} argument missing'),
    ('cli_sandbox', r'unshare failed|bwrap:|failed to create (?:a |new )?(?:pid|user) namespace|'
                    r'credential scrubbing'),
    ('cli_setup', r'\b(?:EACCES|EROFS|ENOSPC)\b|permission denied|read-only file system|'
                  r'cannot find module|command not found'),
)


def error_text(value):
    # SDK errors may be strings or {type, code, message} objects. Do not
    # stringify arbitrary objects or search intermediate assistant/tool turns.
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key in ('type', 'code', 'message'):
            if isinstance(value.get(key), str):
                yield value[key]


def diagnose(response, errors, cli_failed):
    # Bound diagnostics: a malformed response is not a reason to load an entire
    # transcript into memory. Oversized, partial or unparseable JSON cannot pass.
    with response.open('rb') as stream:
        raw = stream.read(MAX_RESPONSE + 1)
    data = None
    if len(raw) > MAX_RESPONSE:
        shape = 'cli_oversized_output'
    elif not raw.strip():
        shape = 'cli_empty_output'
    else:
        try:
            data = json.loads(raw)
            shape = 'cli_no_result'
        except (UnicodeError, ValueError, RecursionError):
            shape = 'cli_non_json_output'
    if isinstance(data, list):  # older CLI versions can emit an array of messages
        data = data[-1] if data else None
    result = data if isinstance(data, dict) and data.get('type') == 'result' else {}
    if result.get('subtype') == 'error_max_turns':
        return 'max_turns'
    complete = (result.get('subtype') == 'success' and result.get('is_error') is False
                and result.get('stop_reason') in (None, 'end_turn', 'stop_sequence'))
    if complete and not cli_failed:
        return 'finished'
    with errors.open('rb') as stream:
        err = stream.read(MAX_STDERR).decode('utf-8', errors='replace')
    details = [err]
    if result:
        shape = 'cli_exit_with_success' if complete else 'cli_error_result'
        details.extend(error_text(result.get('error')))
        if isinstance(result.get('errors'), list):
            for item in result['errors']:
                details.extend(error_text(item))
        if result.get('is_error') is not False or result.get('subtype') != 'success':
            details.extend(error_text(result.get('result')))
    elif isinstance(data, dict) and data.get('type') == 'error':
        details.extend(error_text(data.get('error')))
    elif shape == 'cli_empty_output' and not err:
        shape = 'cli_no_output'
    message = '\n'.join(details)
    for label, pattern in FAILURES:
        if re.search(pattern, message, re.I):
            return label
    return shape if cli_failed else 'invalid_response'


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
