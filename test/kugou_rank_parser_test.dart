import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/kugou_catalog_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses KuGou rank tracks embedded in its HTTPS page', () {
    final result = parseKugouRankHtml('''
      <script>global.features = [
        {"Hash":"hash-1","FileName":"歌手 - 测试&amp;歌曲","author_name":"歌手","timeLen":201.5,"size":3000000,"album_id":1}
      ];</script>
    ''');

    final track = result.items.single;
    expect(track.title, '测试&歌曲');
    expect(track.artist, '歌手');
    expect(track.duration, const Duration(milliseconds: 201500));
    expect(track.extra['hash'], 'hash-1');
  });

  test('enriches KuGou rank artwork through the desktop resource endpoint',
      () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.uri.host == 'www.kugou.com') {
          return handler.resolve(Response<String>(
            requestOptions: options,
            data: '''<script>global.features = [
              {"Hash":"hash-1","FileName":"歌手 - 测试歌曲","author_name":"歌手","timeLen":201,"size":3000000,"album_id":1}
            ];</script>''',
          ));
        }
        expect(options.uri.host, 'media.store.kugou.com');
        expect(options.data['resource'].single['albunm_audio_id'], 'hash-1');
        return handler.resolve(Response<Object?>(
          requestOptions: options,
          data: {
            'data': [
              {
                'hash': 'hash-1',
                'info': {
                  'image': 'http://imge.kugou.com/stdmusic/{size}/cover.jpg',
                },
              },
            ],
          },
        ));
      }));

    final board = (await KugouCatalogService(dio)
            .getLeaderboardBoards(OnlineSource.kugou))
        .first;
    final result = await KugouCatalogService(dio)
        .getLeaderboardDetail(OnlineSource.kugou, board.id, 1);

    expect(result.items.single.coverUri.toString(),
        'https://imge.kugou.com/stdmusic/240/cover.jpg');
  });
}
