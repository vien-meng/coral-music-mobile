import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/song_list/data/kugou_playlist_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses KuGou HTTPS playlist plaza and embedded playlist tracks', () {
    final popular = parseKugouPopularPlaylists({
      'plist': {
        'list': {
          'total': 60,
          'info': [
            {
              'specialid': 1,
              'specialname': '酷狗歌单',
              'songcount': 1,
              'playcount': 12000,
              'imgurl': 'http://img.kugou.com/{size}/cover.jpg',
            },
          ],
        },
      },
    }, page: 1);
    final detail = parseKugouPlaylistDetail(
      '{"list":{"list":{"info":[{"hash":"hash-1","audio_id":2,"filename":"歌手 - 歌曲","album_name":"专辑","duration":1000,"filesize":100,"trans_param":{"union_cover":"http://img.kugou.com/{size}/cover.jpg"}}]}},"info":{"list":{"specialname":"酷狗歌单","nickname":"","intro":"","imgurl":""}}}',
      popular.items.single,
    );

    expect(popular.items.single.source, OnlineSource.kugou);
    expect(detail.playlist.name, '酷狗歌单');
    expect(detail.tracks.single.sourceTrackId, '2');
    expect(detail.tracks.single.coverUri.toString(),
        'https://img.kugou.com/480/cover.jpg');
  });

  test('parses KuGou playlist detail JSON without playlist metadata', () {
    const fallback = OnlinePlaylist(
      id: '1',
      source: OnlineSource.kugou,
      name: '酷狗歌单',
    );
    final detail = parseKugouPlaylistDetail(
      '{"list":{"list":{"info":[{"hash":"hash-1","audio_id":2,"filename":"歌手 - 歌曲","duration":1000,"filesize":100}]}}}',
      fallback,
    );

    expect(detail.tracks.single.sourceTrackId, '2');
  });

  test('parses KuGou HTTPS playlist search results', () {
    final result = parseKugouSearchPlaylists({
      'errcode': 0,
      'data': {
        'total': 1,
        'info': [
          {
            'specialid': 1,
            'specialname': '歌手歌单',
            'imgurl': 'http://img.kugou.com/{size}/cover.jpg',
          },
        ],
      },
    }, page: 1);

    expect(result.items.single.name, '歌手歌单');
    expect(result.items.single.coverUri.toString(),
        'https://img.kugou.com/480/cover.jpg');
  });
}
