import 'dart:math' as math;

/// The confidence level of an estimate that the user can reach a stop before
/// the next bus arrives.
enum CatchabilityStatus { likely, possible, unlikely, departed, unavailable }

class CatchabilityAssessment {
  const CatchabilityAssessment({
    required this.status,
    required this.message,
    this.walkingMinutes,
    this.remainingMinutes,
    this.safetyBufferMinutes = 0,
  });

  final CatchabilityStatus status;
  final String message;
  final int? walkingMinutes;
  final int? remainingMinutes;
  final int safetyBufferMinutes;

  bool get hasEstimate => status != CatchabilityStatus.unavailable;
}

/// Estimates whether a person can walk to a nearby stop before a bus arrives.
///
/// This intentionally uses conservative wording and margins. The nearby-stop
/// distance is a straight-line distance, so [walkingRouteFactor] approximates
/// the extra distance of real streets. [dataDelayBufferMinutes] and the
/// location-accuracy margin cover GPS error, crossings, and realtime delay.
CatchabilityAssessment estimateCatchability({
  required double distanceMeters,
  required int? etaSeconds,
  double? locationAccuracyMeters,
  double walkingSpeedMetersPerMinute = 75,
  double walkingRouteFactor = 1.35,
  int dataDelayBufferMinutes = 2,
}) {
  if (!distanceMeters.isFinite || distanceMeters < 0 || etaSeconds == null) {
    return const CatchabilityAssessment(
      status: CatchabilityStatus.unavailable,
      message: '定位或即時資料不足，無法準確判斷',
    );
  }
  if (!walkingSpeedMetersPerMinute.isFinite ||
      walkingSpeedMetersPerMinute <= 0 ||
      !walkingRouteFactor.isFinite ||
      walkingRouteFactor <= 0 ||
      dataDelayBufferMinutes < 0) {
    return const CatchabilityAssessment(
      status: CatchabilityStatus.unavailable,
      message: '定位或即時資料不足，無法準確判斷',
    );
  }

  if (etaSeconds <= 60) {
    return const CatchabilityAssessment(
      status: CatchabilityStatus.departed,
      message: '公車可能已進站或離站',
    );
  }

  final accuracy = locationAccuracyMeters;
  final accuracyBuffer = accuracy != null && accuracy.isFinite
      ? accuracy >= 100
            ? 2
            : accuracy >= 50
            ? 1
            : 0
      : 0;
  final safetyBufferMinutes = dataDelayBufferMinutes + accuracyBuffer;
  final walkingMinutes = math.max<int>(
    1,
    ((distanceMeters * walkingRouteFactor) / walkingSpeedMetersPerMinute)
        .ceil(),
  );
  // Full minutes are used for the available time so that a partial minute is
  // never presented as spare time.
  final availableMinutes = etaSeconds ~/ 60;
  final remainingMinutes = availableMinutes - walkingMinutes;

  if (remainingMinutes < 0) {
    return CatchabilityAssessment(
      status: CatchabilityStatus.unlikely,
      message: '可能來不及，步行時間約 $walkingMinutes 分鐘；建議搭乘下一班',
      walkingMinutes: walkingMinutes,
      remainingMinutes: remainingMinutes,
      safetyBufferMinutes: safetyBufferMinutes,
    );
  }
  if (remainingMinutes <= safetyBufferMinutes) {
    return CatchabilityAssessment(
      status: CatchabilityStatus.possible,
      message: '可能來得及，步行時間約 $walkingMinutes 分鐘',
      walkingMinutes: walkingMinutes,
      remainingMinutes: remainingMinutes,
      safetyBufferMinutes: safetyBufferMinutes,
    );
  }
  return CatchabilityAssessment(
    status: CatchabilityStatus.likely,
    message: '預估來得及，約剩餘 $remainingMinutes 分鐘',
    walkingMinutes: walkingMinutes,
    remainingMinutes: remainingMinutes,
    safetyBufferMinutes: safetyBufferMinutes,
  );
}
