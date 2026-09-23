import 'package:flutter_test/flutter_test.dart';
import 'package:taiwanbus_flutter/core/catchability_estimator.dart';

void main() {
  test('reports a likely catch with remaining time after walking', () {
    final result = estimateCatchability(
      distanceMeters: 300,
      etaSeconds: 11 * 60,
    );

    expect(result.status, CatchabilityStatus.likely);
    expect(result.walkingMinutes, 6);
    expect(result.remainingMinutes, 5);
    expect(result.message, '預估來得及，約剩餘 5 分鐘');
  });

  test('downgrades a close arrival when GPS accuracy adds a buffer', () {
    final result = estimateCatchability(
      distanceMeters: 300,
      etaSeconds: 8 * 60,
      locationAccuracyMeters: 120,
    );

    expect(result.status, CatchabilityStatus.possible);
    expect(result.safetyBufferMinutes, 4);
    expect(result.message, '可能來得及，步行時間約 6 分鐘');
  });

  test('recommends the next bus when walking takes too long', () {
    final result = estimateCatchability(
      distanceMeters: 600,
      etaSeconds: 10 * 60,
    );

    expect(result.status, CatchabilityStatus.unlikely);
    expect(result.message, contains('可能來不及'));
    expect(result.message, contains('建議搭乘下一班'));
  });

  test('does not promise a bus that is already at the stop', () {
    final result = estimateCatchability(distanceMeters: 20, etaSeconds: 60);

    expect(result.status, CatchabilityStatus.departed);
    expect(result.message, '公車可能已進站或離站');
  });

  test('returns an explicit unavailable message without ETA data', () {
    final result = estimateCatchability(distanceMeters: 200, etaSeconds: null);

    expect(result.status, CatchabilityStatus.unavailable);
    expect(result.hasEstimate, isFalse);
    expect(result.message, '定位或即時資料不足，無法準確判斷');
  });
}
