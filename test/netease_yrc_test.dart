import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/lyric_timeline.dart';
import 'package:coral_music_mobile/features/player/data/netease_yrc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts Netease YRC into karaoke word timings', () {
    final lx = neteaseYrcToLx('[1000,800](1000,300,0)你(1300,500,0)好');
    final line = parseLyricTimeline(LyricPayload(lxlyric: lx)).single;

    expect(lx, '[00:01.000]<1000,300>你<1300,500>好');
    expect(line.words.map((word) => word.start), [
      const Duration(seconds: 1),
      const Duration(milliseconds: 1300),
    ]);
  });
}
