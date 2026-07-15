import 'dart:convert';
import 'dart:io';

import 'package:coral_music_mobile/core/app_failure.dart';
import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/kuwo_leaderboard_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes desktop Kuwo fixture and removes duplicate ids', () {
    final fixture = jsonDecode(
      File('test/fixtures/kuwo_leaderboard_detail.json').readAsStringSync(),
    ) as Map<String, Object?>;

    final result = KuwoLeaderboardParser.parse(fixture, page: 1);

    expect(result.total, 2);
    expect(result.items, hasLength(2));
    expect(result.items.first.id, 'online:kw:1001');
    expect(result.items.first.title, '珊瑚&海');
    expect(result.items.first.artist, '歌手甲、歌手乙');
    expect(result.items.first.availableQualities, [
      AudioQuality.flac,
      AudioQuality.high320k,
    ]);
    expect(result.items.last.coverUri, isNull);
  });

  test('rejects malformed response at the trust boundary', () {
    expect(
      () => KuwoLeaderboardParser.parse(const {'code': 500}, page: 1),
      throwsA(isA<AppFailure>()),
    );
  });
}
