"""Offline: python3 -B -m unittest discover -s tool/mobile-agent-testers/tests -p test_probe.py -v"""
import base64
from contextlib import redirect_stderr, redirect_stdout
from email.message import Message
import io
import json
import os
from pathlib import Path
import socket
import ssl
import struct
import subprocess
import sys
import unittest
from unittest.mock import patch
import zlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import probe

HOST = 'sensitive-proxy.invalid'
KEY = 'private-key-123'
MODEL = 'private-model-123'
ENV = {'LLM_BASE_URL': f'https://{HOST}:8443/prefix/v1/', 'LLM_MODEL': MODEL, 'LLM_API_KEY': KEY}
COLORS = ['green', 'red', 'red', 'blue']
TOKEN = 'private-token-123'
RECEIPT = 'receipt-' + TOKEN
CALL = 'private-call-id'
RAW = 'untrusted-remote-text'


class Response(io.BytesIO):
    def __init__(self, body, mime='text/event-stream', status=200):
        super().__init__(body)
        self.headers = Message()
        self.headers['Content-Type'] = mime + '; charset=utf-8'
        self.status = status
        self.reason = RAW


def frames():
    return [
        {'type': 'message_start', 'message': {'type': 'message', 'role': 'assistant', 'content': []}},
        {'type': 'content_block_start', 'index': 0, 'content_block': {'type': 'text', 'text': ''}},
        {'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'text_delta', 'text': RAW}},
        {'type': 'content_block_stop', 'index': 0},
        {'type': 'content_block_start', 'index': 1,
         'content_block': {'type': 'tool_use', 'id': CALL, 'name': 'report_colors', 'input': {}}},
        {'type': 'content_block_delta', 'index': 1, 'delta': {'type': 'input_json_delta', 'partial_json': '{"colors":'}},
        {'type': 'content_block_delta', 'index': 1, 'delta': {'type': 'input_json_delta', 'partial_json': json.dumps(COLORS) + '}'}},
        {'type': 'content_block_stop', 'index': 1},
        {'type': 'message_delta', 'delta': {'stop_reason': 'tool_use'}},
        {'type': 'message_stop'}]


def stream(entries=None):
    wire = b': keep-alive\r\n\r\n'
    for f in [{'type': 'ping'}] + (frames() if entries is None else entries):
        wire += f'event: {f["type"]}\r\ndata: {json.dumps(f)}\r\n\r\n'.encode()
    return Response(wire)


def final(**changes):
    msg = dict(type='message', role='assistant', stop_reason='end_turn', content=[{'type': 'text', 'text': RECEIPT}])
    return Response(json.dumps(dict(msg, **changes)).encode(), 'application/json')


class Preflight(unittest.TestCase):
    def setUp(self):
        # Intercept the actual transport boundary, not probe.post: exercise
        # URL, headers, TLS configuration, wire bodies and response parsing.
        self.https = self.enter(patch.object(probe.http.client, 'HTTPSConnection'))
        self.enter(patch.object(socket, 'getaddrinfo', side_effect=AssertionError('offline tests only')))
        self.enter(patch.object(probe.secrets, 'token_hex', return_value=TOKEN))
        self.choice = self.enter(patch.object(probe.secrets, 'choice'))
        self.conn = self.https.return_value

    def enter(self, patcher):
        value = patcher.start()
        self.addCleanup(patcher.stop)
        return value

    def invoke(self, *responses, env=None, argv=(), rc=1, reason=None, calls=None):
        self.https.reset_mock()
        self.choice.side_effect = COLORS
        self.conn.getresponse.side_effect = responses
        with patch.dict(os.environ, ENV if env is None else env, clear=True), \
                redirect_stdout(io.StringIO()) as out, redirect_stderr(io.StringIO()) as err:
            code = probe.main(list(argv))
        output = out.getvalue() + err.getvalue()
        self.assertEqual(code, rc, output)
        if calls is not None:
            self.assertEqual(self.conn.request.call_count, calls, output)
        if reason:
            self.assertIn(reason, output)
        if rc:
            self.assertEqual(out.getvalue(), '')
        for secret in (KEY, MODEL, HOST, TOKEN, RAW, CALL, probe.tile_png(COLORS), 'Traceback'):
            self.assertNotIn(secret, output)

    def test_round_trip_binds_pixels_tool_and_result(self):
        self.invoke(stream(), final(), rc=0, calls=2, reason='preflight passed')
        self.assertEqual(self.https.call_count, 2)
        for args, kw in self.https.call_args_list:
            self.assertEqual(args, (HOST, 8443))
            self.assertGreater(kw['timeout'], 0)
            self.assertLessEqual(kw['timeout'], probe.STAGE_TIMEOUT)
            self.assertTrue(kw['context'].check_hostname)
            self.assertEqual(kw['context'].verify_mode, ssl.CERT_REQUIRED)
            self.assertGreaterEqual(kw['context'].minimum_version, ssl.TLSVersion.TLSv1_2)
        requests = []
        for args, kw in self.conn.request.call_args_list:
            method, path, body = args
            self.assertEqual((method, path), ('POST', '/prefix/v1/messages'))
            self.assertEqual(kw['headers']['Authorization'], 'Bearer ' + KEY)
            self.assertEqual(kw['headers']['anthropic-version'], '2023-06-01')
            req = json.loads(body)
            self.assertEqual(req['model'], MODEL)
            self.assertTrue(0 < req['max_tokens'] <= 256)
            self.assertNotIn(KEY.encode(), body)
            requests.append(req)
        first, second = requests
        self.assertTrue(first['stream'])
        self.assertFalse(second['stream'])
        self.assertNotIn('tool_choice', first)  # forcing a tool breaks some reasoning models
        self.assertEqual(len(first['messages']), 1)
        source = first['messages'][0]['content'][0]['source']
        self.assertEqual(source['media_type'], 'image/png')
        self.assertEqual(source['type'], 'base64')
        png = base64.b64decode(source['data'], validate=True)
        self.assertTrue(png.startswith(b'\x89PNG\r\n\x1a\n'))
        width, height = struct.unpack_from('!II', png, 16)
        start = png.index(b'IDAT')
        size, = struct.unpack_from('!I', png, start - 4)
        pixels = zlib.decompress(png[start + 4:start + 4 + size])
        stride = 1 + 3 * width
        self.assertEqual(len(pixels), height * stride)
        for i, color in enumerate(COLORS):
            j = height // 2 * stride + 1 + 3 * ((2 * i + 1) * width // 8)
            self.assertEqual(pixels[j:j + 3], probe.COLORS[color])
        self.assertNotIn(RECEIPT, json.dumps(first))
        self.assertEqual(second['messages'], first['messages'] + [
            {'role': 'assistant', 'content': [{'type': 'text', 'text': RAW},
             {'type': 'tool_use', 'id': CALL, 'name': 'report_colors', 'input': {'colors': COLORS}}]},
            {'role': 'user', 'content': [{'type': 'tool_result', 'tool_use_id': CALL, 'content': RECEIPT}]}])
        self.assertNotIn('tool_choice', second)
        self.assertEqual(second['tools'], first['tools'])
        self.assertEqual(self.conn.close.call_count, 2)

    def test_signed_and_redacted_reasoning_replayed_without_logging(self):
        fs = frames()
        for f in fs:
            if 'index' in f:
                f['index'] += 2
        prefix = [
            {'type': 'content_block_start', 'index': 0, 'content_block': {'type': 'thinking', 'thinking': ''}},
            {'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'thinking_delta', 'thinking': RAW}},
            {'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'signature_delta', 'signature': 'signed-'}},
            {'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'signature_delta', 'signature': RAW}},
            {'type': 'content_block_stop', 'index': 0},
            {'type': 'content_block_start', 'index': 1, 'content_block': {'type': 'redacted_thinking', 'data': RAW}},
            {'type': 'content_block_stop', 'index': 1}]
        fs[1:1] = prefix
        hidden = [{'type': 'thinking', 'thinking': RAW, 'signature': 'signed-' + RAW},
                  {'type': 'redacted_thinking', 'data': RAW}]
        self.invoke(stream(fs), final(content=hidden + [{'type': 'text', 'text': RECEIPT}]), rc=0, calls=2)
        replay = json.loads(self.conn.request.call_args.args[2])['messages'][1]['content']
        self.assertEqual(replay[:2], hidden)
        self.invoke(stream(fs), final(content=hidden), reason='expected one text response', calls=2)

    def test_settings_required_no_vendor_or_proxy_fallback(self):
        fallback = {'ANTHROPIC_BASE_URL': 'https://api.anthropic.com', 'ANTHROPIC_MODEL': MODEL,
                    'ANTHROPIC_AUTH_TOKEN': KEY, 'HTTPS_PROXY': f'https://{HOST}'}
        for name in ENV:
            env = {**fallback, **ENV}
            del env[name]
            self.invoke(env=env, reason='missing ' + name, calls=0)
        for name, value in [('LLM_MODEL', 'default'), ('LLM_API_KEY', KEY + '\r\nX-Test: wrong')]:
            self.invoke(env={**ENV, name: value}, reason='configuration:', calls=0)
        self.https.assert_not_called()

    def test_url_rejection_before_network(self):
        for url in ('https://AnThRoPiC.com', 'https://api.anthropic.com.:443/v1', 'https://foo.claude.ai',
                    'http://' + HOST, HOST, 'https://', 'https://user:' + KEY + '@' + HOST,
                    f'https://{HOST}/v1?key={KEY}', f'https://{HOST}#{KEY}', f'https://{HOST}:99999/',
                    'https://bad host/v1', f'https://{HOST}\\@api.anthropic.com', f'https://{HOST}/a/../b',
                    f'https://{HOST}/v1/messages'):
            with self.subTest(url=url):
                self.invoke(env={**ENV, 'LLM_BASE_URL': url}, reason='configuration:', calls=0)
                self.https.assert_not_called()

    def test_http_errors_are_stage_specific_no_retry_or_redirect(self):
        for stage in (probe.VISION, probe.FOLLOWUP):
            for code, reason in ((307, 'redirect refused'), (400, 'invalid request'), (401, 'authentication failed'),
                                 (403, 'permission denied'), (404, 'endpoint or model not found'), (429, 'rate limited'),
                                 (503, 'request failed')):
                with self.subTest(stage=stage, code=code):
                    error = Response(RAW.encode(), status=code)
                    error.headers['Location'] = 'https://api.anthropic.com/' + KEY
                    responses = [error] if stage == probe.VISION else [stream(), error]
                    self.invoke(*responses, calls=len(responses), reason=f'{stage}: HTTP {code} ({reason})')

    def test_transport_errors_safe(self):
        for exc, why in [(ssl.SSLCertVerificationError(RAW), 'TLS certificate verification failed'),
                         (ssl.SSLError(RAW), 'TLS connection failed'), (socket.gaierror(RAW), 'DNS lookup failed'),
                         (TimeoutError(RAW), 'socket timed out'), (ConnectionResetError(RAW), 'HTTP transport')]:
            self.conn.request.side_effect = exc
            self.invoke(reason=probe.VISION + ': ' + why, calls=1)
            self.conn.close.assert_called_once()

    def test_bad_stream_framing_and_limits(self):
        cases = [(final(), 'expected text/event-stream'), (stream(frames()[:-1]), 'stream ended before message_stop'),
                 (Response(b'event: ping\ndata: ' + RAW.encode() + b'\n\n'), 'malformed stream event JSON'),
                 (Response(b'event: ping\ndata: {"type":"message_stop"}\n\n'), 'stream event name/type mismatch'),
                 (Response(b':' * (probe.MAX_LINE + 1)), 'stream size limit'),
                 (Response((b':' * 1024 + b'\n') * (probe.MAX_BYTES // 1024 + 1)), 'stream size limit'),
                 (stream([{'type': 'ping'}] * probe.MAX_EVENTS), 'stream event limit'),
                 (stream([{'type': 'error', 'error': {'type': 'rate_limit_error', 'message': RAW}}]), 'provider error: rate limited')]
        for res, reason in cases:
            with self.subTest(reason=reason):
                self.invoke(res, calls=1, reason=probe.VISION + ': ' + reason)

    def test_requires_real_streamed_tool_input_and_visual_answer(self):
        for change, why in [
            (lambda f: f.pop(0), 'unexpected stream event order'),
            (lambda f: f[4].update(index=4), 'invalid stream block index'),
            (lambda f: f[4]['content_block'].update(name=RAW), 'unexpected tool call'),
            (lambda f: f[4]['content_block'].update(id=''), 'invalid tool_use ID'),
            (lambda f: f.__delitem__(slice(5, 7)), 'missing streamed tool input'),
            (lambda f: f[5]['delta'].update(partial_json=RAW), 'malformed tool input JSON'),
            (lambda f: f[6]['delta'].update(partial_json='["yellow"]}'), 'did not identify the image'),
            (lambda f: f.__delitem__(slice(4, 8)), 'missing tool_use block'),
            (lambda f: f[8]['delta'].update(stop_reason='max_tokens'), 'expected tool_use stop reason')]:
            with self.subTest(why=why):
                fs = frames()
                change(fs)
                self.invoke(stream(fs), calls=1, reason=why)

    def test_followup_requires_receipt_not_any_200(self):
        for res, why in [(stream(), 'expected application/json'),
                         (Response(b'x' * (probe.MAX_BYTES + 1), 'application/json'), 'response size limit'),
                         (Response(RAW.encode(), 'application/json'), 'malformed follow-up JSON'),
                         (final(type='error', error={'type': KEY, 'message': RAW}), 'provider error: request failed'),
                         (final(stop_reason='tool_use'), 'expected completed assistant turn'),
                         (final(content=[]), 'expected one text response'),
                         (final(content=[{'type': 'text', 'text': RAW}]), 'tool_result receipt was not returned exactly')]:
            with self.subTest(why=why):
                self.invoke(stream(), res, calls=2, reason=probe.FOLLOWUP + ': ' + why)

    def test_cli_never_echoes_unknown_arguments(self):
        self.invoke(argv=[KEY], rc=2, reason='Usage:', calls=0)
        self.invoke(argv=['--help'], env={}, rc=0, reason='LLM_BASE_URL', calls=0)

    def test_deadline_even_if_transport_stalls(self):
        code = ('import probe,time\nprobe.STAGE_TIMEOUT = 0.05\n'
                'with probe.stage(probe.FOLLOWUP): time.sleep(30)')
        result = subprocess.run([sys.executable, '-B', '-c', code], cwd=ROOT, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b'multi-turn tool_result: wall-clock deadline exceeded', result.stderr)


if __name__ == '__main__':
    unittest.main()
