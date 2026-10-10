import 'dart:math' as math;

/// Per-screen retry state. Successful updates restore the user's interval;
/// failures slow down, while Retry-After is always a lower bound.
class RefreshBackoff {
  RefreshBackoff({double Function()? random})
    : _random = random ?? math.Random().nextDouble;

  final double Function() _random;
  int _failures = 0;

  int nextSeconds({
    required bool succeeded,
    required int normalSeconds,
    required int errorSeconds,
    Duration? retryAfter,
  }) {
    if (succeeded) {
      _failures = 0;
    } else {
      _failures = math.min(_failures + 1, 7);
    }
    var seconds = math.max(1, normalSeconds);
    if (!succeeded) {
      final base = math.max(seconds, errorSeconds);
      seconds = math.min(60, base * (1 << (_failures - 1)));
      seconds = math.min(60, seconds + (seconds * 0.2 * _random()).ceil());
    }
    if (retryAfter != null) {
      seconds = math.max(seconds, (retryAfter.inMilliseconds / 1000).ceil());
    }
    return seconds;
  }
}
