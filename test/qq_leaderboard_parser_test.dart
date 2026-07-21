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
    expect(result.items.first.coverUri.toString(),
        'https://y.gtimg.cn/music/photo_new/T002R500x500M000000pKXff1doeOd.jpg');
    expect(result.items.last.availableQualities, [AudioQuality.flac24bit]);
    expect(result.items.last.coverUri.toString(),
        'https://y.gtimg.cn/music/photo_new/T001R500x500M000singer2.jpg');
  });

  test('normalizes QQ search tracks and preserves result pagination', () {
    final result = QqLeaderboardParser.parseSearch(
      {
        'code': 0,
        'req': {
          'code': 0,
          'data': {
            'meta': {'estimate_sum': 81},
            'body': {
              'item_song': [
                {
                  'mid': 'search-mid',
                  'id': 42,
                  'title': '搜索歌曲',
                  'interval': 215,
                  'singer': [
                    {'name': '搜索歌手', 'mid': 'singer-mid'},
                  ],
                  'album': {'name': '搜索专辑', 'mid': 'album-mid'},
                  'file': {
                    'media_mid': 'media-mid',
                    'size_flac': 30000000,
                    'size_320mp3': 8000000,
                  },
                },
              ],
            },
          },
        },
      },
      page: 2,
    );

    expect(result.page, 2);
    expect(result.total, 81);
    expect(result.items.single.id, 'online:tx:search-mid');
    expect(result.items.single.artist, '搜索歌手');
    expect(result.items.single.album, '搜索专辑');
    expect(result.items.single.duration, const Duration(seconds: 215));
    expect(result.items.single.availableQualities,
        [AudioQuality.flac, AudioQuality.high320k]);
    expect(result.items.single.coverUri.toString(),
        'https://y.gtimg.cn/music/photo_new/T002R500x500M000album-mid.jpg');
    expect(result.items.single.extra['mediaMid'], 'media-mid');
    expect(result.items.single.extra['qualityMeta'], {
      'flac': {'size': 30000000},
      '320k': {'size': 8000000},
    });
  });
}
