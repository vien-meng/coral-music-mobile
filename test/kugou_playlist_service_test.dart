import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/song_list/data/kugou_playlist_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses KuGou HTTPS playlist plaza', () {
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

    expect(popular.items.single.source, OnlineSource.kugou);
    expect(popular.items.single.name, '酷狗歌单');
  });

  test('parses KuGou playlist detail from mobilecdn API', () {
    final detail = parseKugouPlaylistDetailV3(
      {
        'data': {
          'specialname': '酷狗歌单',
          'nickname': '作者名',
          'intro': '简介',
          'imgurl': 'http://img.kugou.com/{size}/cover.jpg',
        },
      },
      {
        'data': {
          'total': 1,
          'info': [
            {
              'hash': 'hash-1',
              'audio_id': 2,
              'filename': '歌手 - 歌曲',
              'duration': 240,
              'filesize': 100,
              '320hash': 'hash-320',
              '320filesize': 200,
              'sqhash': 'hash-sq',
              'sqfilesize': 300,
              'trans_param': {
                'union_cover': 'http://img.kugou.com/{size}/cover.jpg',
              },
            },
          ],
        },
      },
      const OnlinePlaylist(
        id: '1',
        source: OnlineSource.kugou,
        name: '酷狗歌单',
      ),
    );

    expect(detail.playlist.name, '酷狗歌单');
    expect(detail.playlist.author, '作者名');
    expect(detail.tracks.single.sourceTrackId, 'hash-1');
    expect(detail.tracks.single.coverUri.toString(),
        'https://img.kugou.com/480/cover.jpg');
  });

  test('parses KuGou playlist detail without playlist metadata', () {
    final detail = parseKugouPlaylistDetailV3(
      const {},
      {
        'data': {
          'info': [
            {
              'hash': 'hash-1',
              'audio_id': 2,
              'filename': '歌手 - 歌曲',
              'duration': 240,
              'filesize': 100,
            },
          ],
        },
      },
      const OnlinePlaylist(
        id: '1',
        source: OnlineSource.kugou,
        name: '酷狗歌单',
      ),
    );

    expect(detail.tracks.single.sourceTrackId, 'hash-1');
    expect(detail.playlist.name, '酷狗歌单');
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
