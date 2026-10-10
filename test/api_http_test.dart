import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwanbus_flutter/core/api_http.dart';

void main() {
  test(
    'body deadline aborts a stalled response and preserves the shared client',
    () async {
      var cancelled = false;
      var aborted = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      var calls = 0;
      final transport = MockClient.streaming((request, _) async {
        calls++;
        if (calls > 1) {
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
        }
        expect(request, isA<http.Abortable>());
        unawaited(
          (request as http.Abortable).abortTrigger!.then((_) {
            aborted = true;
          }),
        );
        return http.StreamedResponse(body.stream, 200);
      });
      final client = TimedHttpClient(
        transport,
        timeout: const Duration(milliseconds: 40),
      );
      await expectLater(
        client.get(Uri.parse('https://test.invalid/slow')),
        throwsA(isA<TimeoutException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      expect(aborted, isTrue);
      expect(
        (await client.get(Uri.parse('https://test.invalid/fast'))).body,
        '{}',
      );
      await body.close();
      client.close();
    },
  );

  test('JSON deadline is total even when the body keeps trickling', () async {
    final body = StreamController<List<int>>();
    final ticks = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => body.add([32]),
    );
    final client = TimedHttpClient(
      MockClient.streaming(
        (_, _) async => http.StreamedResponse(body.stream, 200),
      ),
      timeout: const Duration(milliseconds: 50),
    );
    try {
      await expectLater(
        client.get(Uri.parse('https://test.invalid/trickle')),
        throwsA(isA<TimeoutException>()),
      );
    } finally {
      ticks.cancel();
      await body.close();
      client.close();
    }
  });

  test(
    '429 exposes Retry-After and prevents another transport request during cooldown',
    () async {
      var calls = 0;
      final client = TimedHttpClient(
        MockClient((_) async {
          calls++;
          return http.Response('limited', 429, headers: {'retry-after': '120'});
        }),
      );
      final uri = Uri.parse('https://test.invalid/routes');
      for (var i = 0; i < 2; i++) {
        await expectLater(
          client.get(uri),
          throwsA(
            isA<ApiRequestException>()
                .having((e) => e.statusCode, 'status', 429)
                .having(
                  (e) => e.retryAfter.inSeconds,
                  'retry seconds',
                  greaterThanOrEqualTo(119),
                ),
          ),
        );
      }
      expect(calls, 1);
      client.close();
    },
  );

  test('Retry-After accepts HTTP dates, seconds and malformed input', () {
    final now = DateTime.utc(2026, 10, 10);
    expect(
      parseApiRetryAfter('Sat, 10 Oct 2026 00:01:00 GMT', now: now),
      const Duration(minutes: 1),
    );
    expect(parseApiRetryAfter('15'), const Duration(seconds: 15));
    expect(parseApiRetryAfter('bad'), isNull);
    expect(parseApiRetryAfter('-5'), Duration.zero);
  });

  test('city-map cooldown does not consume the normal route budget', () async {
    final client = TimedHttpClient(
      MockClient(
        (request) async => request.url.path.endsWith('/buses')
            ? http.Response('limited', 429, headers: {'retry-after': '60'})
            : http.Response('{}', 200),
      ),
    );
    await expectLater(
      client.get(Uri.parse('https://test.invalid/api/v1/cities/Taipei/buses')),
      throwsA(isA<ApiRequestException>()),
    );
    expect(
      (await client.get(
        Uri.parse('https://test.invalid/api/v1/routes/TPE307/realtime'),
      )).statusCode,
      200,
    );
    client.close();
  });

  test('API headers advertise Brotli before gzip', () {
    expect(apiJsonHeaders['Accept-Encoding'], 'br, gzip');
    expect(apiJsonHeaders['Accept'], 'application/json');
  });

  test('apiResponseText decodes Brotli response bodies', () {
    const encoded = <int>[
      139,
      5,
      128,
      104,
      101,
      108,
      108,
      111,
      32,
      98,
      114,
      111,
      116,
      108,
      105,
      3,
    ];
    final response = http.Response.bytes(
      encoded,
      200,
      headers: const {'Content-Encoding': 'br'},
    );

    expect(apiResponseText(response), 'hello brotli');
  });

  test('async decoder preserves small JSON values and UTF-8', () async {
    for (final value in <Object?>[
      null,
      42,
      ['臺北車站', true],
      {'stops': [], 'name': '公車'},
    ]) {
      final response = http.Response.bytes(utf8.encode(jsonEncode(value)), 200);
      expect(await apiDecodeJsonResponseAsync(response), value);
    }
  });

  test(
    'large JSON can cross the isolate boundary without losing data',
    () async {
      final stops = List.generate(
        5000,
        (index) => {'stopid': index, 'name': '測試站 $index', 'eta': null},
      );
      final response = http.Response.bytes(utf8.encode(jsonEncode(stops)), 200);
      expect(response.bodyBytes.length, greaterThan(64 * 1024));
      expect(await apiDecodeJsonResponseAsync(response), stops);
    },
  );

  test('async decoder handles Brotli and already decoded bodies', () async {
    // Brotli uncompressed block containing the JSON string "hello brotli".
    final compressed = http.Response.bytes(
      [139, 6, 128, ...utf8.encode('"hello brotli"'), 3],
      200,
      headers: {'Content-Encoding': 'br'},
    );
    expect(await apiDecodeJsonResponseAsync(compressed), 'hello brotli');
    final decoded = http.Response.bytes(
      utf8.encode('{"name":"臺北"}'),
      200,
      headers: {'Content-Encoding': 'br'},
    );
    expect(await apiDecodeJsonResponseAsync(decoded), {'name': '臺北'});
  });

  test('async decoder propagates malformed JSON from both paths', () async {
    for (final body in ['{', '${' ' * (64 * 1024)}{']) {
      await expectLater(
        apiDecodeJsonResponseAsync(http.Response(body, 200)),
        throwsFormatException,
      );
    }
  });
}
