import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/app_motion.dart';
import '../l10n/app_localizations.dart';

class EtaBadge extends StatelessWidget {
  const EtaBadge({
    required this.stop,
    required this.alwaysShowSeconds,
    this.size = 58,
    this.isLoading = false,
    super.key,
  });

  final StopInfo stop;
  final bool alwaysShowSeconds;
  final double size;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final eta = buildEtaPresentation(
      stop,
      alwaysShowSeconds: alwaysShowSeconds,
      brightness: theme.brightness,
      colorScheme: theme.colorScheme,
      arrivingText: l10n.etaArriving,
      secondsText: l10n.etaSeconds,
      minutesText: l10n.etaMinutes,
      minutesSecondsText: l10n.etaMinutesSeconds,
    );
    final fontSize = size * 0.24;

    return AnimatedContainer(
      duration: AppMotion.duration(context),
      curve: AppMotion.curve,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isLoading
            ? theme.colorScheme.surfaceContainerHighest
            : eta.backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.duration(context),
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.curve,
        child: Text(
          key: ValueKey((isLoading, isLoading ? l10n.etaLoading : eta.text)),
          isLoading ? l10n.etaLoading : eta.text,
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 2,
          style: TextStyle(
            color: isLoading
                ? theme.colorScheme.onSurfaceVariant
                : eta.foregroundColor,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// A generic ETA badge that accepts seconds directly.
/// Useful for metro, rail, and other transit systems.
class GenericEtaBadge extends StatelessWidget {
  const GenericEtaBadge({
    required this.seconds,
    this.message,
    this.size = 58,
    this.darkBackground = false,
    super.key,
  });

  final int? seconds;
  final String? message;
  final double size;
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final eta = buildGenericEtaPresentation(
      seconds: seconds,
      message: message,
      brightness: theme.brightness,
      colorScheme: theme.colorScheme,
      arrivingText: l10n.etaArriving,
      secondsText: l10n.etaSeconds,
      minutesText: l10n.etaMinutes,
    );
    final fontSize = size * 0.24;
    final backgroundColor = darkBackground
        ? _darkenEtaColor(eta.backgroundColor)
        : eta.backgroundColor;

    return AnimatedContainer(
      duration: AppMotion.duration(context),
      curve: AppMotion.curve,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.duration(context),
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.curve,
        child: Text(
          eta.text,
          key: ValueKey(eta.text),
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 2,
          style: TextStyle(
            color: darkBackground ? Colors.white : eta.foregroundColor,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

Color _darkenEtaColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  const maximumLightness = 0.32;
  if (hsl.lightness <= maximumLightness) {
    return color;
  }
  return hsl.withLightness(maximumLightness).toColor();
}

/// Build ETA presentation from raw seconds.
EtaPresentation buildGenericEtaPresentation({
  required int? seconds,
  String? message,
  Brightness brightness = Brightness.light,
  ColorScheme? colorScheme,
  String arrivingText = '進站中',
  String Function(int seconds)? secondsText,
  String Function(int minutes)? minutesText,
}) {
  final isDark = brightness == Brightness.dark;
  final cs = colorScheme;

  if (message != null && message.isNotEmpty) {
    return EtaPresentation(
      text: formatEtaBadgeText(message),
      backgroundColor:
          cs?.primaryContainer ??
          (isDark ? const Color(0xFF16383D) : Colors.teal.shade50),
      foregroundColor:
          cs?.onPrimaryContainer ??
          (isDark ? const Color(0xFFBEECEF) : Colors.teal.shade900),
    );
  }

  if (seconds == null) {
    return EtaPresentation(
      text: '--',
      backgroundColor: cs?.surfaceContainerHighest ?? const Color(0xFF364152),
      foregroundColor: cs?.onSurfaceVariant ?? const Color(0xFFD8E2F1),
    );
  }

  if (seconds <= 0) {
    return EtaPresentation(
      text: arrivingText,
      backgroundColor: Colors.red.shade800,
      foregroundColor: Colors.white,
    );
  }

  if (seconds < 60) {
    // For metro, show "即將到站" instead of exact seconds
    return EtaPresentation(
      text: secondsText?.call(seconds) ?? '$seconds秒',
      backgroundColor: Colors.red.shade600,
      foregroundColor: Colors.white,
    );
  }

  final minutes = seconds ~/ 60;
  final urgent = minutes < 3;

  return EtaPresentation(
    text: minutesText?.call(minutes) ?? '$minutes分',
    backgroundColor: urgent
        ? Colors.orange.shade700
        : (cs?.primary ??
              (isDark ? const Color(0xFF233A41) : const Color(0xFFE2F4F1))),
    foregroundColor: urgent
        ? Colors.white
        : (cs?.onSurface ??
              (isDark ? const Color(0xFFD7F1F3) : const Color(0xFF0D4E57))),
  );
}
