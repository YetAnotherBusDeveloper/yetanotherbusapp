"""Billed CPA preflight: python3 tool/mobile-agent-testers/probe.py (no arguments).

Set LLM_BASE_URL (HTTPS CPA root or /v1), LLM_MODEL and LLM_API_KEY in the
process environment. At most two POSTs, no retries. Exit 0 only if both pass.
The workflow runs this once before starting the persona matrix.
"""
import base64
from contextlib import contextmanager
import http.client
import json
import os
from pathlib import Path
import secrets
import socket
import ssl
import struct
import sys
import threading
from urllib.parse import urlsplit
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parent / 'runtime' / 'scripts'))
from cpa_config import validate_config

SOCKET_TIMEOUT = 15  # inactivity, seconds
STAGE_TIMEOUT = 45   # includes DNS, TLS handshake, headers and slow-drip bodies
MAX_BYTES = 128 * 1024
MAX_LINE = 16 * 1024
MAX_EVENTS = 512
MAX_TOKENS = 160
VISION = 'image input / streamed tool call'
FOLLOWUP = 'multi-turn tool_result'
COLORS = {'red': b'\xff\x00\x00', 'green': b'\x00\xbb\x00',
          'blue': b'\x00\x00\xff', 'yellow': b'\xff\xff\x00'}
TOOL = {'name': 'report_colors', 'description': 'Report the tile colors from left to right.',
        'input_schema': {'type': 'object', 'properties': {
            'colors': {'type': 'array', 'items': {'type': 'string', 'enum': list(COLORS)}}},
            'required': ['colors'], 'additionalProperties': False}}


class Failure(Exception):
    """May contain only locally authored diagnostics, never untrusted text."""


def tile_png(colors):
    """Construct a tiny RGB PNG. The correct order appears only in the pixels."""
    def chunk(tag, data):
        return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data))

    row = (b'\xff' * 12).join(COLORS[c] * 48 for c in colors)
    header = struct.pack('!IIBBBBB', len(row) // 3, 48, 8, 2, 0, 0, 0)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress((b'\0' + row) * 48)) + chunk(b'IEND', b'')
    return base64.b64encode(png).decode('ascii')


@contextmanager
def stage(name):
    # A socket timeout alone cannot bound getaddrinfo or a peer sending one
    # byte at a time. This single-purpose CLI has no persistent state to unwind.
    def deadline():
        try:
            os.write(2, f'CPA {name}: wall-clock deadline exceeded.\n'.encode())
        finally:
            os._exit(1)

    timer = threading.Timer(STAGE_TIMEOUT, deadline)
    timer.daemon = True
    timer.start()
    try:
        yield
    except Failure as exc:
        raise Failure(f'{name}: {exc}') from None
    except ssl.SSLCertVerificationError:
        raise Failure(f'{name}: TLS certificate verification failed') from None
    except ssl.SSLError:
        raise Failure(f'{name}: TLS connection failed') from None
    except socket.gaierror:
        raise Failure(f'{name}: DNS lookup failed') from None
    except TimeoutError:
        raise Failure(f'{name}: socket timed out') from None
    except (http.client.HTTPException, OSError):
        raise Failure(f'{name}: HTTP transport or connection failed') from None
    except Exception:
        raise Failure(f'{name}: unexpected local error') from None
    finally:
        timer.cancel()


@contextmanager
def post(root, key, body, mime):
    url = urlsplit(root)
    # No urllib proxy handlers, redirect processing, SDK defaults or retries.
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)  # CERT_REQUIRED + check_hostname
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_default_certs()
    conn = http.client.HTTPSConnection(url.hostname, url.port or 443, timeout=SOCKET_TIMEOUT, context=ctx)
    try:
        conn.request('POST', url.path + '/v1/messages', json.dumps(body).encode(), headers={
            'Authorization': 'Bearer ' + key, 'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json', 'Accept': mime})
        with conn.getresponse() as res:
            if res.status != 200:
                reasons = {400: 'invalid request', 401: 'authentication failed', 403: 'permission denied',
                           404: 'endpoint or model not found', 413: 'request too large',
                           415: 'unsupported media type', 429: 'rate limited', 529: 'overloaded'}
                reason = 'redirect refused' if 300 <= res.status < 400 else reasons.get(res.status, 'request failed')
                raise Failure(f'HTTP {res.status:d} ({reason})')
            if res.headers.get_content_type() != mime:
                raise Failure(f'expected {mime} response')
            yield res
    finally:
        conn.close()


def obj(data, label):
    try:
        value = json.loads(data)
    except (ValueError, RecursionError):
        raise Failure(f'malformed {label} JSON') from None
    if not isinstance(value, dict):
        raise Failure(f'{label} is not a JSON object')
    return value


def check_error(frame):
    if frame.get('type') == 'error':
        err = frame.get('error')
        kind = err.get('type') if isinstance(err, dict) else None
        # Never show the provider message or an arbitrary error type.
        known = {'authentication_error': 'authentication failed', 'permission_error': 'permission denied',
                 'rate_limit_error': 'rate limited', 'overloaded_error': 'overloaded',
                 'invalid_request_error': 'invalid request', 'not_found_error': 'endpoint or model not found'}
        raise Failure('provider error: ' + (known.get(kind, 'request failed') if isinstance(kind, str) else 'request failed'))


def events(res):
    used = count = 0
    event, data = b'', []
    while True:
        line = res.readline(MAX_LINE + 1)
        if not line:
            raise Failure('stream ended before message_stop')
        used += len(line)
        if len(line) > MAX_LINE or used > MAX_BYTES:
            raise Failure('stream size limit exceeded')
        line = line.rstrip(b'\r\n')
        if line:
            field, _, value = line.partition(b':')
            if field == b'event':
                event = value.strip()
            elif field == b'data':
                data.append(value.removeprefix(b' '))
            continue  # includes SSE comments / keepalives
        if data:
            count += 1
            if count > MAX_EVENTS:
                raise Failure('stream event limit exceeded')
            frame = obj(b'\n'.join(data), 'stream event')
            if not event.isascii() or event.decode('ascii') != frame.get('type'):
                raise Failure('stream event name/type mismatch')
            check_error(frame)
            if frame['type'] != 'ping':
                yield frame
        event, data = b'', []


# Anthropic reasoning models may emit a signed thinking prefix. Preserve its
# opaque contents in the assistant turn; never interpret it as text or log it.
DELTA_FIELDS = {('tool_use', 'input_json_delta'): 'partial_json', ('text', 'text_delta'): 'text',
                ('thinking', 'thinking_delta'): 'thinking', ('thinking', 'signature_delta'): 'signature'}


def start_block(raw, call_id):
    if not isinstance(raw, dict):
        raise Failure('missing stream content block')
    kind = raw.get('type')
    if kind == 'tool_use':
        if call_id or raw.get('name') != TOOL['name']:
            raise Failure('duplicate or unexpected tool call')
        ident = raw.get('id')
        if not isinstance(ident, str) or not ident.strip() or raw.get('input') != {}:
            raise Failure('invalid tool_use ID or starting input')
        return {'type': kind, 'id': ident, 'name': TOOL['name']}
    if kind == 'thinking':
        fields = ['thinking'] + (['signature'] if 'signature' in raw else [])
    elif kind == 'text':
        fields = ['text']
    elif kind == 'redacted_thinking':
        fields = ['data']
    else:
        raise Failure('unexpected stream block type')
    if not all(isinstance(raw.get(f), str) for f in fields):
        raise Failure('invalid stream content block')
    return {'type': kind, **{f: raw[f] for f in fields}}


def append_delta(block, delta):
    if not isinstance(delta, dict) or not isinstance(delta.get('type'), str):
        raise Failure('invalid stream content delta')
    field = DELTA_FIELDS.get((block['type'], delta['type']))
    if field is None or not isinstance(delta.get(field), str):
        raise Failure('invalid stream content delta')
    block[field] = block.get(field, '') + delta[field]


def streamed_call(res, colors):
    """Reconstruct and replay only completed, understood assistant blocks."""
    blocks = []
    started = finished = False
    block = call_id = None
    for frame in events(res):
        kind = frame['type']
        if kind == 'message_start' and not started:
            msg = frame.get('message')
            if not isinstance(msg, dict) or msg.get('role') != 'assistant' or msg.get('content') != []:
                raise Failure('invalid assistant message_start')
            started = True
        elif kind == 'message_stop' and finished:
            return blocks, call_id
        elif not started or finished:
            raise Failure('unexpected stream event order')
        elif kind == 'message_delta' and block is None:
            if not call_id:
                raise Failure('missing tool_use block')
            delta = frame.get('delta')
            if not isinstance(delta, dict) or delta.get('stop_reason') != 'tool_use':
                raise Failure('expected tool_use stop reason')
            finished = True
        elif kind in ('content_block_start', 'content_block_delta', 'content_block_stop'):
            if type(frame.get('index')) is not int or frame['index'] != len(blocks):
                raise Failure('invalid stream block index')
            if kind == 'content_block_start' and block is None:
                block = start_block(frame.get('content_block'), call_id)
            elif kind == 'content_block_delta' and block is not None:
                append_delta(block, frame.get('delta'))
            elif kind == 'content_block_stop' and block is not None:
                if block['type'] == 'tool_use':
                    if not block.get('partial_json'):
                        raise Failure('missing streamed tool input')
                    args = obj(block.pop('partial_json'), 'tool input')
                    if args != {'colors': colors}:
                        raise Failure('tool input did not identify the image tiles in order')
                    block['input'] = args
                    call_id = block['id']
                blocks.append(block)
                block = None
            else:
                raise Failure('unexpected stream block order')
        else:
            raise Failure('unexpected or incomplete stream event sequence')


def verify(env):
    values = []
    for name in ('LLM_BASE_URL', 'LLM_MODEL', 'LLM_API_KEY'):
        if not env.get(name):
            raise Failure(f'configuration: missing {name}')
        values.append(env[name])
    base, model, key = values
    try:
        root = validate_config(base, model, key)
    except ValueError as exc:  # shared validator contract: fixed, non-sensitive reasons
        raise Failure(f'configuration: {exc}') from None

    colors = [secrets.choice(list(COLORS)) for _ in range(4)]
    messages = [{'role': 'user', 'content': [
        {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/png', 'data': tile_png(colors)}},
        {'type': 'text', 'text': 'Call report_colors with the four tile colors from left to right. '
         'After the tool returns, reply with only its receipt, exactly as received.'}]}]
    common = {'model': model, 'max_tokens': MAX_TOKENS, 'tools': [TOOL], 'messages': messages}
    with stage(VISION), post(root, key, dict(common, stream=True), 'text/event-stream') as res:
        blocks, call_id = streamed_call(res, colors)

    receipt = 'receipt-' + secrets.token_hex(8)
    messages.extend([{'role': 'assistant', 'content': blocks}, {'role': 'user', 'content': [
        {'type': 'tool_result', 'tool_use_id': call_id, 'content': receipt}]}])
    with stage(FOLLOWUP), post(root, key, dict(common, stream=False), 'application/json') as res:
        payload = res.read(MAX_BYTES + 1)
        if len(payload) > MAX_BYTES:
            raise Failure('response size limit exceeded')
        msg = obj(payload, 'follow-up')
        check_error(msg)
        if msg.get('type') != 'message' or msg.get('role') != 'assistant' or msg.get('stop_reason') != 'end_turn':
            raise Failure('expected completed assistant turn')
        content = msg.get('content')
        if not isinstance(content, list) or not all(isinstance(b, dict) for b in content):
            raise Failure('invalid follow-up content blocks')
        visible = [b for b in content if b.get('type') not in ('thinking', 'redacted_thinking')]
        if len(visible) != 1 or visible[0].get('type') != 'text':
            raise Failure('expected one text response to tool_result')
        text = visible[0].get('text')
        if not isinstance(text, str) or text.strip() != receipt:
            raise Failure('tool_result receipt was not returned exactly')


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv in (['--help'], ['-h']):
        print(__doc__)
        return 0
    if argv:
        print('Usage: python3 tool/mobile-agent-testers/probe.py (settings via environment only)', file=sys.stderr)
        return 2
    try:
        verify(os.environ)
    except Failure as exc:
        print(f'CPA preflight failed: {exc}', file=sys.stderr)
        return 1
    except Exception:
        # Never render an exception from a URL parser, transport or remote body.
        print('CPA preflight failed: unexpected local error.', file=sys.stderr)
        return 1
    print('CPA preflight passed: image input, streaming, tool call and multi-turn tool_result.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
