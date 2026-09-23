enum TransitNameLanguage { zh, en }

TransitNameLanguage transitNameLanguageForLocale(String locale) {
  final normalized = locale.trim().toLowerCase().replaceAll('_', '-');
  return normalized == 'en' || normalized.startsWith('en-')
      ? TransitNameLanguage.en
      : TransitNameLanguage.zh;
}

String? normalizeTransitNamePart(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

class TransitName {
  const TransitName({this.zh, this.en, required this.stableId});

  final String? zh;
  final String? en;
  final String stableId;

  String forLanguage(TransitNameLanguage language) {
    final primary = _part(language);
    final alternate = _part(_alternate(language));
    return primary ?? alternate ?? stableId.trim();
  }

  String forLocale(String locale) {
    return forLanguage(transitNameLanguageForLocale(locale));
  }

  String get chinesePrimary =>
      _part(TransitNameLanguage.zh) ??
      _part(TransitNameLanguage.en) ??
      stableId.trim();

  String? foreignSecondaryForLocale(String locale) {
    final normalizedLocale = locale.trim().toLowerCase().replaceAll('_', '-');
    if (normalizedLocale == 'zh' || normalizedLocale.startsWith('zh-')) {
      return null;
    }

    final foreign = _part(TransitNameLanguage.en);
    if (foreign == null ||
        _normalized(foreign) == _normalized(chinesePrimary)) {
      return null;
    }
    return foreign;
  }

  String stationDisplayForLocale(String locale, {String separator = '\n'}) {
    final secondary = foreignSecondaryForLocale(locale);
    return secondary == null
        ? chinesePrimary
        : '$chinesePrimary$separator$secondary';
  }

  /// Formats a transit name for UI display.
  ///
  /// Chinese interfaces show only Chinese. Other interfaces keep Chinese as
  /// the secondary name after the preferred English name.
  String displayForLocale(String locale, {String separator = ' / '}) {
    final normalizedLocale = locale.trim().toLowerCase().replaceAll('_', '-');
    final isChinese =
        normalizedLocale == 'zh' || normalizedLocale.startsWith('zh-');
    if (isChinese) {
      return forLanguage(TransitNameLanguage.zh);
    }
    return bilingual(TransitNameLanguage.en, separator: separator);
  }

  String bilingual(TransitNameLanguage language, {String separator = ' / '}) {
    final primary = _part(language);
    final alternate = _part(_alternate(language));
    if (primary == null) {
      return alternate ?? stableId.trim();
    }
    if (alternate == null || _normalized(primary) == _normalized(alternate)) {
      return primary;
    }
    return '$primary$separator$alternate';
  }

  String bilingualForLocale(String locale, {String separator = ' / '}) {
    return bilingual(
      transitNameLanguageForLocale(locale),
      separator: separator,
    );
  }

  String? _part(TransitNameLanguage language) {
    return normalizeTransitNamePart(
      language == TransitNameLanguage.zh ? zh : en,
    );
  }

  TransitNameLanguage _alternate(TransitNameLanguage language) {
    return language == TransitNameLanguage.zh
        ? TransitNameLanguage.en
        : TransitNameLanguage.zh;
  }

  String _normalized(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}
