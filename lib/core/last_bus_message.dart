final RegExp _lastBusIgnoredCharacters = RegExp(
  r'[\s\u200B-\u200D\uFEFF，。！？、：；,.!?;:()（）\[\]［］{}【】「」『』<>《》〈〉_\-/]+',
);

final RegExp _lastBusDeparturePattern = RegExp(
  r'(?:末班(?:公車|班車|車)?|最後一班(?:公車|車)?)(?:已經|已|己)?(?:駛離|離站|開走|發車|駛過|過站|過了|過)',
);

/// Whether an ETA message says that the final bus has already departed.
bool isLastBusMessage(String? message) {
  if (message == null || message.isEmpty) {
    return false;
  }
  final normalized = message.toLowerCase().replaceAll(
    _lastBusIgnoredCharacters,
    '',
  );
  return _lastBusDeparturePattern.hasMatch(normalized);
}
