import '../../../domain/music.dart';

final class LyricLine {
  const LyricLine({
    required this.at,
    required this.text,
    this.translation,
    this.romanization,
    this.words = const [],
  });

  final Duration at;
  final String text;
  final String? translation;
  final String? romanization;
  final List<LyricWord> words;
}

final class LyricWord {
  const LyricWord(
      {required this.start, required this.duration, required this.text});

  final Duration start;
  final Duration duration;
  final String text;
}

List<LyricLine> parseLyricTimeline(LyricPayload payload) {
  final translations = _parse(payload.tlyric);
  final romanizations = _parse(payload.rlyric);
  final source = payload.lxlyric.contains(RegExp(r'<\d+,\d+>'))
      ? payload.lxlyric
      : payload.lyric;
  final offset = _parseOffset(source);
  final originals = _parse(source).values.toList()
    ..sort((left, right) => left.at.compareTo(right.at));
  return originals.map(
    (line) {
      final words = _parseWords(line.text, offset);
      return LyricLine(
        at: line.at + offset,
        text: words.isEmpty ? line.text : words.map((word) => word.text).join(),
        translation: translations[line.at.inMilliseconds]?.text,
        romanization: romanizations[line.at.inMilliseconds]?.text,
        words: words,
      );
    },
  ).toList(growable: false);
}

List<LyricWord> _parseWords(String raw, Duration offset) {
  final tag = RegExp(r'<(\d+),(\d+)>');
  final matches = tag.allMatches(raw).toList();
  if (matches.isEmpty) return const [];
  final words = <LyricWord>[];
  for (var index = 0; index < matches.length; index++) {
    final match = matches[index];
    final text = raw.substring(
      match.end,
      index + 1 < matches.length ? matches[index + 1].start : raw.length,
    );
    if (text.trim().isEmpty) continue;
    words.add(LyricWord(
      start: Duration(milliseconds: int.parse(match.group(1)!)) + offset,
      duration: Duration(milliseconds: int.parse(match.group(2)!)),
      text: text,
    ));
  }
  return words;
}

Duration _parseOffset(String raw) {
  final value = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false)
      .firstMatch(raw)
      ?.group(1);
  return Duration(milliseconds: int.tryParse(value ?? '') ?? 0);
}

Map<int, _TimedText> _parse(String raw) {
  final lines = <int, _TimedText>{};
  final tag = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
  for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
    final matches = tag.allMatches(rawLine).toList();
    if (matches.isEmpty) continue;
    final text = rawLine.replaceAll(tag, '').trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = (match.group(3) ?? '').padRight(3, '0');
      final milliseconds = fraction.isEmpty ? 0 : int.parse(fraction);
      final at = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
      lines[at.inMilliseconds] = _TimedText(at, text);
    }
  }
  return lines;
}

final class _TimedText {
  const _TimedText(this.at, this.text);

  final Duration at;
  final String text;
}
