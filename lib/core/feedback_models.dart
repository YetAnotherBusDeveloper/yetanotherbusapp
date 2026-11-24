enum FeedbackCategory { bug, data, feature, other }

/// Only the app/display fields shown in the feedback consent preview.
class FeedbackDiagnostics {
  const FeedbackDiagnostics({
    required this.appVersion,
    required this.buildNumber,
    required this.commitHash,
    required this.platform,
    required this.locale,
    required this.screenWidth,
    required this.screenHeight,
    required this.textScale,
    required this.brightness,
  });

  final String appVersion;
  final String buildNumber;
  final String commitHash;
  final String platform;
  final String locale;
  final int screenWidth;
  final int screenHeight;
  final double textScale;
  final String brightness;

  Map<String, Object> toJson() => {
    'app_version': appVersion,
    'build_number': buildNumber,
    'commit_hash': commitHash,
    'platform': platform,
    'locale': locale,
    'screen_width': screenWidth,
    'screen_height': screenHeight,
    'text_scale': textScale,
    'brightness': brightness,
  };
}
