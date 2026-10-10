import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/refresh_backoff.dart';

void main() {
  test('failures slow down, honor long Retry-After, and reset on success', () {
    final backoff = RefreshBackoff(random: () => 0);
    int next(bool success, {Duration? retryAfter}) => backoff.nextSeconds(
      succeeded: success,
      normalSeconds: 10,
      errorSeconds: 3,
      retryAfter: retryAfter,
    );
    expect(next(false), 10);
    expect(next(false), 20);
    expect(next(false), 40);
    expect(next(false), 60);
    expect(next(false), 60);
    expect(next(false, retryAfter: const Duration(milliseconds: 120500)), 121);
    expect(next(true), 10);
    expect(next(false), 10);
  });
}
