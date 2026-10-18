import 'package:flutter/material.dart';

/// A route's full name in the rounded square `EtaBadge` uses, so route and
/// station cards line up in mixed favourite groups.
///
/// The whole name is always shown; long names break onto a second line (see
/// [routeBadgeLines]) and shrink to fit rather than being cut short.
class RouteNameBadge extends StatelessWidget {
  const RouteNameBadge({required this.name, this.size = 52, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lines = routeBadgeLines(name);
    // The card title already reads the route name out.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(size * 0.31),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            lines.isEmpty ? '?' : lines.join('\n'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.33,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

const _lineSeparators = {' ', '-', '－', '–', '—', '/', '／', '、', '·'};
const _openingBrackets = {'(', '（', '[', '【', '〔'};
final _codeCharacter = RegExp(r'^[0-9A-Za-z]$');

/// The one or two lines a [RouteNameBadge] shows for [name].
///
/// Up to four characters stay on one line. Longer names break at the
/// candidate nearest the middle: a separator, which is dropped ("19路 大灣→安平"
/// → 19路 / 大灣→安平); an opening bracket, which starts the second line; or
/// a switch between ASCII letters/digits and other text, which is where route
/// numbers meet their wording ("152區2" → 152 / 區2, "市民小巴4延" → 市民小巴 /
/// 4延). Pure codes such as "7327D" stay whole; other names with no candidate
/// are halved.
List<String> routeBadgeLines(String name) {
  final characters = name.trim().characters.toList(growable: false);
  if (characters.isEmpty) {
    return const [];
  }
  if (characters.length <= 4) {
    return [characters.join()];
  }

  bool isCode(String character) => _codeCharacter.hasMatch(character);
  final middle = characters.length / 2;
  int? firstLineEnd;
  int? secondLineStart;
  var bestDistance = double.infinity;
  for (var index = 1; index < characters.length; index++) {
    final previous = characters[index - 1];
    final current = characters[index];
    if (_lineSeparators.contains(previous)) {
      continue;
    }
    final isSeparator = _lineSeparators.contains(current);
    if (!isSeparator &&
        !_openingBrackets.contains(current) &&
        isCode(previous) == isCode(current)) {
      continue;
    }
    final distance = (index - middle).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      firstLineEnd = index;
      secondLineStart = isSeparator ? index + 1 : index;
    }
  }

  if (firstLineEnd == null || secondLineStart == null) {
    if (characters.every(isCode)) {
      return [characters.join()];
    }
    firstLineEnd = secondLineStart = (characters.length / 2).ceil();
  }
  final firstLine = characters.sublist(0, firstLineEnd).join().trim();
  final secondLine = characters.sublist(secondLineStart).join().trim();
  if (firstLine.isEmpty || secondLine.isEmpty) {
    return [characters.join()];
  }
  return [firstLine, secondLine];
}
