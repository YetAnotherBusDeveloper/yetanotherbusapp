"""Shared, offline CPA policy. Never put input values or URL parser errors in logs."""
import ipaddress
import os
import re
import sys
from urllib.parse import urlsplit, urlunsplit


def validate_config(base_url: str, model: str, key: str) -> str:
    """Return the SDK base URL (Messages API appends /v1/messages itself)."""
    if not re.fullmatch(r'[!-~]+', key):
        raise ValueError('Missing or invalid CPA key.')
    if (not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9./:+_()-]*', model)
            or model.lower() in {'default', 'opus', 'sonnet', 'haiku', 'fable', 'opusplan', 'best', 'inherit'}):
        raise ValueError('Supply an explicit CPA model ID, not a CLI alias.')
    if (not base_url.startswith('https://') or not re.fullmatch(r'[!-~]+', base_url)
            or any(c in base_url for c in '@?#\\%')):
        raise ValueError('CPA requires an HTTPS base URL without credentials, query or fragment.')
    try:
        url = urlsplit(base_url)
        host = (url.hostname or '').removesuffix('.')
        port = url.port  # validates decimal and range
        if not host or port == 0 or url.netloc.endswith(':'):
            raise ValueError
        if url.netloc.startswith('['):
            ipaddress.IPv6Address(host)
            if not re.fullmatch(r'\[[0-9A-Fa-f:.]+\](?::[0-9]+)?', url.netloc):
                raise ValueError
        elif (not re.fullmatch(r'[A-Za-z0-9.-]+(?::[0-9]+)?', url.netloc) or len(host) > 253
              or not all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', label) for label in host.split('.'))):
            raise ValueError
    except ValueError:
        raise ValueError('Invalid CPA hostname or port.') from None
    if any(host == name or host.endswith('.' + name) for name in ('anthropic.com', 'claude.ai')):
        raise ValueError('A direct Anthropic API URL is not a CPA endpoint.')
    if ('//' in url.path or any(seg in {'.', '..'} for seg in url.path.split('/'))
            or not re.fullmatch(r'[A-Za-z0-9/_~.\-]*', url.path)):
        raise ValueError('Invalid CPA path prefix.')
    path = url.path.removesuffix('/')
    if path.endswith('/messages'):
        raise ValueError('Supply the CPA base URL, not the Messages API resource.')
    return urlunsplit(('https', url.netloc, path.removesuffix('/v1'), '', ''))


if __name__ == '__main__':
    try:
        base = validate_config(*(os.environ.get(name, '') for name in ('LLM_BASE_URL', 'LLM_MODEL', 'LLM_API_KEY')))
    except ValueError as exc:
        sys.exit(str(exc))
    # Used ONLY in a shell command substitution inside the private launcher.
    if sys.argv[1:] == ['--sdk-base']:
        print(base)
