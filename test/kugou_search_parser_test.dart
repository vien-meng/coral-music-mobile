import 'dart:convert';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/kugou_search_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a JSON body sent as text/plain', () {
    final result = KugouSearchParser.parse(
      jsonEncode({
        'error_code': 0,
        'data': {
          'total': 1,
          'lists': [
            {
              'Audioid': 1,
              'FileHash': 'hash',
              'SongName': '文本响应歌曲',
              'Singers': const [],
              'FileSize': 1,
            },
          ],
        },
      }),
      page: 1,
    );

    expect(result.items.single.title, '文本响应歌曲');
  });

  test('normalizes Kugou search tracks and keeps quality hashes', () {
    final result = KugouSearchParser.parse(
      {
        'error_code': 0,
        'data': {
          'total': 81,
          'lists': [
            {
              'Audioid': 123,
              'FileHash': '128-hash',
              'SongName': '测试歌曲',
              'Singers': [
                {'name': '歌手甲'},
                {'name': '歌手乙'},
              ],
              'AlbumName': '测试专辑',
              'AlbumID': 456,
              'Image': 'http://imge.kugou.com/stdmusic/{size}/cover.jpg',
              'Duration': 215,
              'FileSize': 3000000,
              'HQFileHash': '320-hash',
              'HQFileSize': 8000000,
              'SQFileHash': 'flac-hash',
              'SQFileSize': 30000000,
              'Grp': [
                {
                  'Audioid': 124,
                  'FileHash': 'child-hash',
                  'SongName': '子歌曲',
                  'Singers': {'name': '子歌手'},
                  'FileSize': 2000000,
                },
              ],
            },
          ],
        },
      },
      page: 2,
    );

    expect(result.page, 2);
    expect(result.pageSize, 30);
    expect(result.total, 81);
    expect(result.items, hasLength(2));
    final track = result.items.first;
    expect(track.id, 'online:kg:128-hash');
    expect(track.artist, '歌手甲、歌手乙');
    expect(track.duration, const Duration(seconds: 215));
    expect(track.coverUri.toString(),
        'https://imge.kugou.com/stdmusic/480/cover.jpg');
    expect(track.availableQualities, [
      AudioQuality.flac,
      AudioQuality.high320k,
      AudioQuality.standard128k,
    ]);
    final qualities = track.extra['qualityMeta']! as Map<String, Object?>;
    expect((qualities['flac']! as Map)['hash'], 'flac-hash');
    expect((qualities['320k']! as Map)['size'], 8000000);
    expect(result.items.last.artist, '子歌手');
  });
}
