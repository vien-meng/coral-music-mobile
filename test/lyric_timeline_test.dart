import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/lyric_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aligns LRC text and translation by timestamp', () {
    final lines = parseLyricTimeline(const LyricPayload(
      lyric: '[00:01.20]第一句\n[00:03.000]第二句',
      tlyric: '[00:01.200]First\n[00:03.00]Second',
      rlyric: '[00:01.200]di yi ju\n[00:03.00]di er ju',
    ));

    expect(lines.map((line) => line.at), [
      const Duration(seconds: 1, milliseconds: 200),
      const Duration(seconds: 3),
    ]);
    expect(lines.map((line) => line.translation), ['First', 'Second']);
    expect(lines.map((line) => line.romanization), ['di yi ju', 'di er ju']);
  });

  test('orders LRC lines by timestamp instead of source line order', () {
    final lines = parseLyricTimeline(const LyricPayload(
      lyric: '[00:03.00]第三句\n[00:01.00]第一句\n[00:02.00]第二句',
    ));

    expect(lines.map((line) => line.text), ['第一句', '第二句', '第三句']);
  });

  test('prefers LX LRC and retains word timing', () {
    final lines = parseLyricTimeline(const LyricPayload(
      lyric: '[00:01.00]普通歌词',
      lxlyric: '[00:01.00]<1000,200>逐<1200,300>字',
    ));

    expect(lines.single.text, '逐字');
    expect(lines.single.words.map((word) => word.start), [
      const Duration(seconds: 1),
      const Duration(milliseconds: 1200),
    ]);
  });

  test('preserves whitespace between timed LX words', () {
    final lines = parseLyricTimeline(const LyricPayload(
      lxlyric: '[00:01.00]<1000,200>Hello <1200,300>world',
    ));

    expect(lines.single.text, 'Hello world');
  });

  test('applies an LRC offset to lines and timed words', () {
    final lines = parseLyricTimeline(const LyricPayload(
      lxlyric: '[offset:250]\n[00:01.00]<1000,200>词',
    ));

    expect(lines.single.at, const Duration(milliseconds: 1250));
    expect(lines.single.words.single.start, const Duration(milliseconds: 1250));
  });

  test('converts desktop Kuwo signed timing into karaoke words', () {
    final lines = parseLyricTimeline(const LyricPayload(
      lyric: '[kuwo:127]\n[00:01.00]<1232,-1232>为<2640,176>你',
    ));

    expect(lines.single.text, '为你');
    expect(lines.single.words.map((word) => word.text), ['为', '你']);
    expect(lines.single.words.map((word) => word.start), [
      const Duration(seconds: 1),
      const Duration(seconds: 1, milliseconds: 176),
    ]);
    expect(
        lines.single.words.first.duration, const Duration(milliseconds: 176));
  });

  test('keeps untimed lyrics as readable fallback lines', () {
    expect(
      parsePlainLyricLines(const LyricPayload(
        lyric: '[ar:歌手]\n第一句\n[00:00.00]第二句\n<100,200>第三句',
      )),
      ['第一句', '第二句', '第三句'],
    );
  });
}
