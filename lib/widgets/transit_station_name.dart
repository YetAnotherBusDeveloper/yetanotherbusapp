import 'package:flutter/material.dart';

import '../core/transit_name.dart';

class TransitStationName extends StatelessWidget {
  const TransitStationName({
    super.key,
    required this.name,
    this.primaryStyle,
    this.secondaryStyle,
    this.primaryMaxLines = 1,
    this.secondaryMaxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final TransitName name;
  final TextStyle? primaryStyle;
  final TextStyle? secondaryStyle;
  final int primaryMaxLines;
  final int secondaryMaxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final secondary = name.foreignSecondaryForLocale(locale);
    final resolvedPrimaryStyle = primaryStyle ?? theme.textTheme.bodyLarge;
    final primaryFontSize = resolvedPrimaryStyle?.fontSize;
    final resolvedSecondaryStyle =
        secondaryStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: primaryFontSize == null
              ? null
              : (primaryFontSize * 0.72).clamp(11.0, 14.0),
          height: 1.15,
        );

    return Semantics(
      label: name.stationDisplayForLocale(locale, separator: ', '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            name.chinesePrimary,
            style: resolvedPrimaryStyle,
            textAlign: textAlign,
            maxLines: primaryMaxLines,
            overflow: overflow,
          ),
          if (secondary != null)
            Text(
              secondary,
              style: resolvedSecondaryStyle,
              textAlign: textAlign,
              maxLines: secondaryMaxLines,
              overflow: overflow,
            ),
        ],
      ),
    );
  }
}

class TransitDirectionLabel extends StatelessWidget {
  const TransitDirectionLabel({
    super.key,
    required this.label,
    this.primaryStyle,
    this.secondaryStyle,
    this.textAlign = TextAlign.center,
  });

  final String label;
  final TextStyle? primaryStyle;
  final TextStyle? secondaryStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = label.split('\n');
    final primary = parts.first.trim();
    final secondary = parts.skip(1).join(' ').trim();
    final resolvedPrimaryStyle = primaryStyle ?? theme.textTheme.bodyMedium;
    final primaryFontSize = resolvedPrimaryStyle?.fontSize;

    return Semantics(
      label: label.replaceAll('\n', ', '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            primary,
            style: resolvedPrimaryStyle,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (secondary.isNotEmpty)
            Text(
              secondary,
              style:
                  secondaryStyle ??
                  theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: primaryFontSize == null
                        ? null
                        : (primaryFontSize * 0.72).clamp(10.0, 13.0),
                    height: 1.1,
                  ),
              textAlign: textAlign,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
