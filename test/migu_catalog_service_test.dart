import 'package:coral_music_mobile/features/leaderboard/data/migu_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes a relative Migu search cover URL', () {
    final result = MiguCatalogService.parseSearch({
      'songResultData': {
        'totalCount': 1,
        'resultList': [
          [
            {
              'songId': 'song-1',
              'name': '歌曲',
              'singerList': const [],
              'album': '专辑',
              'duration': 180,
              'img3': '/music/cover.jpg',
              'lrcUrl': 'https://example.com/song.lrc',
              'mrcurl': 'https://example.com/song.mrc',
              'trcUrl': 'https://example.com/song.trc',
              'audioFormats': const [],
            },
          ],
        ],
      },
    }, 1);

    expect(result.items.single.coverUri.toString(),
        'https://d.musicapp.migu.cn/music/cover.jpg');
    expect(result.items.single.extra['lrcUrl'], 'https://example.com/song.lrc');
    expect(result.items.single.extra['mrcUrl'], 'https://example.com/song.mrc');
    expect(result.items.single.extra['trcUrl'], 'https://example.com/song.trc');
  });
}
