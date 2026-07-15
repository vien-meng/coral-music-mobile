import 'dart:convert';
import 'dart:io';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/qq_leaderboard_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes QQ leaderboard tracks and file qualities', () async {
    final text =
        await File('test/fixtures/qq_leaderboard_detail.json').readAsString();
    final result =
        QqLeaderboardParser.parse(jsonDecode(text) as Map<String, Object?>);

    expect(result.items, hasLength(2));
    expect(result.items.first.id, 'online:tx:000Tx0ZM2xaBhM');
    expect(result.items.first.artist, 'Sweety、测试歌手');
    expect(result.items.first.duration, const Duration(seconds: 283));
    expect(
      result.items.first.availableQualities,
      [AudioQuality.flac, AudioQuality.high320k, AudioQuality.standard128k],
    );
    expect(result.items.first.extra['mediaMid'], '002Y0Eb148Eyan');
    expect(result.items.last.availableQualities, [AudioQuality.flac24bit]);
    expect(result.items.last.coverUri.toString(), contains('T001singer2'));
  });
}
