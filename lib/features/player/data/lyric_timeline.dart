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
  final rawSource =
      payload.lxlyric.isNotEmpty ? payload.lxlyric : payload.lyric;
  final kuwoRelativeWords = RegExp(r'<-?\d+,-\d+').hasMatch(rawSource);
  final source = _normalizeKuwoWordTiming(rawSource);
  final offset = _parseOffset(source);
  final originals = _parse(source).values.toList()
    ..sort((left, right) => left.at.compareTo(right.at));
  return originals.map(
    (line) {
      final words = _parseWords(
        line.text,
        offset + (kuwoRelativeWords ? line.at : Duration.zero),
      );
      return LyricLine(
        at: line.at + offset,
        text: words.isEmpty
            ? _stripWordMarkers(line.text)
            : words.map((word) => word.text).join(),
        translation: translations[line.at.inMilliseconds]?.text,
        romanization: romanizations[line.at.inMilliseconds]?.text,
        words: words,
      );
    },
  ).toList(growable: false);
}

List<String> parsePlainLyricLines(LyricPayload payload) {
  final raw = [payload.lyric, payload.lxlyric, payload.tlyric, payload.rlyric]
      .where((value) => value.trim().isNotEmpty)
      .firstOrNull;
  if (raw == null) return const [];
  final timeTag = _timeTag;
  final metadata = RegExp(
    r'\[(?:ar|ti|al|by|offset|kuwo):[^\]]*\]',
    caseSensitive: false,
  );
  return raw
      .split(RegExp(r'\r?\n'))
      .map((line) => _stripWordMarkers(line)
          .replaceAll(timeTag, '')
          .replaceAll(metadata, '')
          .trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

List<LyricWord> _parseWords(String raw, Duration offset) {
  final tag = RegExp(r'<(\d+),(\d+)>');
  final matches = tag.allMatches(raw).toList();
  if (matches.isEmpty) return const [];
  final words = <LyricWord>[];
  for (var index = 0; index < matches.length; index++) {
    final match = matches[index];
    final text = '${index == 0 ? raw.substring(0, match.start) : ''}'
        '${raw.substring(match.end, index + 1 < matches.length ? matches[index + 1].start : raw.length)}';
    if (text.trim().isEmpty) continue;
    words.add(LyricWord(
      start: Duration(milliseconds: int.parse(match.group(1)!)) + offset,
      duration: Duration(milliseconds: int.parse(match.group(2)!)),
      text: text,
    ));
  }
  return words;
}

String _stripWordMarkers(String raw) =>
    raw.replaceAll(RegExp(r'<-?\d+,-?\d+(?:,-?\d+)?>'), '');

/// Converts Kuwo's signed word offsets to the desktop-compatible LX form.
///
/// Kuwo encodes each word as `<offset,delta>` and calibrates it with `[kuwo:]`.
/// The desktop client performs this conversion before rendering karaoke lyrics.
String _normalizeKuwoWordTiming(String raw) {
  final signedTag = RegExp(r'<-?\d+,-?\d+(?:,-?\d+)?>');
  if (!signedTag.hasMatch(raw) || !RegExp(r'<-?\d+,-\d+').hasMatch(raw)) {
    return raw;
  }

  var offset = 1;
  var offset2 = 1;
  return raw.split(RegExp(r'\r?\n')).map((line) {
    final kuwo = RegExp(r'\[kuwo:\s*([^\]]+)]', caseSensitive: false)
        .firstMatch(line)
        ?.group(1);
    if (kuwo != null) {
      final value = int.tryParse(kuwo.trim(), radix: 8);
      if (value != null) {
        final first = value ~/ 10;
        final second = value % 10;
        if (first != 0 && second != 0) {
          offset = first;
          offset2 = second;
        }
      }
    }
    final tags = signedTag.allMatches(line).toList();
    if (tags.isEmpty) return line;

    final starts = <int>[];
    final ends = <int>[];
    for (final tag in tags) {
      final first = int.parse(tag.group(0)!.split(RegExp(r'[<,>]'))[1]);
      final second = int.parse(tag.group(0)!.split(RegExp(r'[<,>]'))[2]);
      final start = ((first + second).abs() / (offset * 2)).round();
      final end = ((first - second).abs() / (offset2 * 2)).round() + start;
      if (ends.isNotEmpty && start < ends.last) {
        ends[ends.length - 1] = start < starts.last ? starts.last : start;
      }
      starts.add(start);
      ends.add(end);
    }
    final normalized = StringBuffer();
    var cursor = 0;
    for (var index = 0; index < tags.length; index++) {
      final tag = tags[index];
      normalized.write(line.substring(cursor, tag.start));
      normalized.write('<${starts[index]},${ends[index] - starts[index]}>');
      cursor = tag.end;
    }
    normalized.write(line.substring(cursor));
    return normalized.toString();
  }).join('\n');
}

Duration _parseOffset(String raw) {
  final value = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false)
      .firstMatch(raw)
      ?.group(1);
  return Duration(milliseconds: int.tryParse(value ?? '') ?? 0);
}

Map<int, _TimedText> _parse(String raw) {
  final lines = <int, _TimedText>{};
  final tag = _timeTag;
  for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
    final matches = tag.allMatches(rawLine).toList();
    if (matches.isEmpty) continue;
    final text = rawLine.replaceAll(tag, '').trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
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

/// Standard LRC uses `[mm:ss.xx]`; Kuwo's detail endpoint uses `[seconds.xx]`.
final _timeTag = RegExp(r'\[(?:(\d{1,2}):)?(\d{1,3})(?:[.:](\d{1,3}))?\]');

final class _TimedText {
  const _TimedText(this.at, this.text);

  final Duration at;
  final String text;
}
