import 'dart:async';
import 'dart:convert';

import 'package:brotli/brotli.dart' as brotli;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const apiAcceptedEncodings = 'br, gzip';
const apiCompressionHeaders = <String, String>{
  'Accept-Encoding': apiAcceptedEncodings,
};
const apiJsonHeaders = <String, String>{
  'Accept': 'application/json',
  ...apiCompressionHeaders,
};
const apiJsonContentHeaders = <String, String>{
  ...apiJsonHeaders,
  'Content-Type': 'application/json',
};

const apiRequestTimeout = Duration(seconds: 15);
const apiDownloadIdleTimeout = Duration(seconds: 30);

Future<http.Response> apiGet(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
}) {
  return _timed(client).get(uri, headers: headers);
}

Future<http.Response> apiPost(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
  Object? body,
}) {
  return _timed(client).post(uri, headers: headers, body: body);
}

Future<http.Response> apiPut(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
  Object? body,
}) {
  return _timed(client).put(uri, headers: headers, body: body);
}

TimedHttpClient _timed(http.Client client) =>
    client is TimedHttpClient ? client : TimedHttpClient(client);

class ApiRequestException extends http.ClientException {
  ApiRequestException(this.statusCode, this.retryAt, Uri uri)
    : super(
        statusCode == 429 ? '你已受到速率限制。 (429)' : '服務暫時無法使用。 ($statusCode)',
        uri,
      );

  final int statusCode;
  final DateTime retryAt;
  Duration get retryAfter {
    final remaining = retryAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

Duration? parseApiRetryAfter(String? value, {DateTime? now}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final seconds = int.tryParse(text);
  if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
  // HTTP-date (RFC 9110), parsed without dart:io so Web can read it too.
  final match = RegExp(
    r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(text);
  if (match == null) return null;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months.indexOf(match[2]!);
  if (month < 0) return null;
  final date = DateTime.utc(
    int.parse(match[3]!),
    month + 1,
    int.parse(match[1]!),
    int.parse(match[4]!),
    int.parse(match[5]!),
    int.parse(match[6]!),
  );
  final delay = date.difference(now ?? DateTime.now());
  return delay.isNegative ? Duration.zero : delay;
}

class TimedHttpClient extends http.BaseClient {
  TimedHttpClient(this._delegate, {this.timeout = apiRequestTimeout});

  final http.Client _delegate;
  final Duration timeout;
  final Map<String, DateTime> _cooldowns = {};

  String _cooldownKey(Uri uri) =>
      RegExp(r'^/api/v1/cities/[^/]+/buses$').hasMatch(uri.path)
      ? '${uri.origin}:city-buses'
      : uri.origin;

  Duration? retryAfterFor(Uri uri) {
    final key = _cooldownKey(uri);
    final until = _cooldowns[key];
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _cooldowns.remove(key);
      return null;
    }
    return remaining;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);

  /// Large downloads have an idle timeout; JSON calls have a total deadline.
  Future<http.StreamedResponse> sendStreaming(http.BaseRequest request) =>
      _send(request, idleTimeout: apiDownloadIdleTimeout);

  Future<http.StreamedResponse> _send(
    http.BaseRequest request, {
    Duration? idleTimeout,
  }) async {
    final cooldownKey = _cooldownKey(request.url);
    if (retryAfterFor(request.url) != null) {
      throw ApiRequestException(429, _cooldowns[cooldownKey]!, request.url);
    }
    final abort = Completer<void>();
    void cancelRequest() {
      if (!abort.isCompleted) abort.complete();
    }

    final clock = Stopwatch()..start();
    final wrapped = _AbortableRequest(request, abort.future);
    http.StreamedResponse response;
    try {
      response = await _delegate
          .send(wrapped)
          .timeout(
            timeout,
            onTimeout: () {
              cancelRequest();
              throw TimeoutException('API response deadline exceeded', timeout);
            },
          );
    } catch (_) {
      cancelRequest();
      rethrow;
    }
    if (response.statusCode == 429 ||
        (response.statusCode == 503 &&
            response.headers.containsKey('retry-after'))) {
      final delay =
          parseApiRetryAfter(response.headers['retry-after']) ??
          const Duration(seconds: 30);
      final until = DateTime.now().add(delay);
      final previous = _cooldowns[cooldownKey];
      if (previous == null || previous.isBefore(until)) {
        _cooldowns[cooldownKey] = until;
      }
      cancelRequest();
      unawaited(response.stream.listen((_) {}).cancel());
      throw ApiRequestException(
        response.statusCode,
        _cooldowns[cooldownKey]!,
        request.url,
      );
    }

    late StreamController<List<int>> output;
    StreamSubscription<List<int>>? subscription;
    Timer? timer;
    var finished = false;
    void expire() {
      if (finished) return;
      finished = true;
      cancelRequest();
      output.addError(TimeoutException('API body deadline exceeded', timeout));
      unawaited(subscription?.cancel());
      unawaited(output.close());
    }

    void startTimer() {
      timer?.cancel();
      final remaining = idleTimeout ?? timeout - clock.elapsed;
      timer = Timer(remaining.isNegative ? Duration.zero : remaining, expire);
    }

    output = StreamController<List<int>>(
      sync: true,
      onListen: () {
        startTimer();
        subscription = response.stream.listen(
          (bytes) {
            if (finished) return;
            if (idleTimeout != null) startTimer();
            output.add(bytes);
          },
          onError: (Object error, StackTrace stack) {
            if (finished) return;
            finished = true;
            timer?.cancel();
            output.addError(error, stack);
            unawaited(output.close());
          },
          onDone: () {
            if (finished) return;
            finished = true;
            timer?.cancel();
            unawaited(output.close());
          },
          cancelOnError: true,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        timer?.cancel();
        // A completed source has already closed itself. Cancelling it again
        // can make completion depend on an unrelated zone's cancellation Future.
        if (finished) return null;
        cancelRequest();
        finished = true;
        return subscription?.cancel();
      },
    );
    return http.StreamedResponse(
      output.stream,
      response.statusCode,
      contentLength: response.contentLength,
      headers: response.headers,
      request: response.request,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _delegate.close();
}

class _AbortableRequest extends http.BaseRequest implements http.Abortable {
  _AbortableRequest(this.original, Future<void> deadline)
    : abortTrigger = original is http.Abortable && original.abortTrigger != null
          ? Future.any([deadline, original.abortTrigger!])
          : deadline,
      super(original.method, original.url) {
    headers.addAll(original.headers);
    contentLength = original.contentLength;
    followRedirects = original.followRedirects;
    maxRedirects = original.maxRedirects;
    persistentConnection = original.persistentConnection;
  }

  final http.BaseRequest original;
  @override
  final Future<void> abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return original.finalize();
  }
}

List<int> apiResponseBodyBytes(http.Response response) {
  return _decodeBodyBytes(response.bodyBytes, _contentEncodings(response));
}

List<int> _decodeBodyBytes(List<int> bytes, List<String> encodings) {
  for (final encoding in encodings.reversed) {
    switch (encoding) {
      case 'br':
        bytes = _tryDecode(() => brotli.brotli.decode(bytes), bytes);
        break;
      case 'gzip':
      case 'x-gzip':
      case 'identity':
        break;
    }
  }
  return bytes;
}

String apiResponseText(http.Response response) {
  return utf8.decode(apiResponseBodyBytes(response));
}

Object? apiDecodeJsonResponse(http.Response response) {
  return jsonDecode(apiResponseText(response));
}

/// Offloads decompression, UTF-8 and JSON decoding for expensive native
/// responses. Small plain responses avoid the cost of starting an isolate.
/// Web uses the same decoder but remains on the browser's main thread.
Future<Object?> apiDecodeJsonResponseAsync(http.Response response) async {
  final encodings = _contentEncodings(response);
  final payload = (response.bodyBytes, encodings);
  if (!kIsWeb &&
      (response.bodyBytes.length >= 64 * 1024 || encodings.contains('br'))) {
    return compute(_decodeJsonPayload, payload, debugLabel: 'api.decodeJson');
  }
  return _decodeJsonPayload(payload);
}

Object? _decodeJsonPayload((Uint8List, List<String>) payload) {
  return jsonDecode(utf8.decode(_decodeBodyBytes(payload.$1, payload.$2)));
}

List<String> _contentEncodings(http.Response response) {
  final header = response.headers.entries
      .where((entry) => entry.key.toLowerCase() == 'content-encoding')
      .map((entry) => entry.value)
      .firstOrNull;
  if (header == null || header.trim().isEmpty) {
    return const [];
  }
  return header
      .split(',')
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

List<int> _tryDecode(List<int> Function() decode, List<int> fallback) {
  try {
    return decode();
  } catch (_) {
    return fallback;
  }
}
