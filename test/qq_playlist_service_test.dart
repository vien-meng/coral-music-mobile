import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/song_list/data/qq_playlist_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes QQ playlist plaza entries', () {
    final result = QqPlaylistService.parsePopular(
      {
        'code': 0,
        'playlist': {
          'code': 0,
          'data': {
            'total': 81,
            'v_playlist': [
              {
                'tid': 123,
                'title': '夏日歌单',
                'creator_info': {'nick': '创建者'},
                'desc': '描述<br>换行',
                'song_ids': [1, 2],
                'access_num': 12000,
                'cover_url_medium': 'http://cover.example.com/cover.jpg',
              },
            ],
          },
        },
      },
      page: 2,
    );

    expect(result.page, 2);
    expect(result.pageSize, 30);
    expect(result.total, 81);
    final playlist = result.items.single;
    expect(playlist.source, OnlineSource.qq);
    expect(playlist.id, '123');
    expect(playlist.trackCount, 2);
    expect(playlist.playCount, '1.2万');
    expect(playlist.description, '描述\n换行');
    expect(playlist.coverUri.toString(), 'https://cover.example.com/cover.jpg');
  });

  test('normalizes QQ playlist detail tracks and qualities', () {
    const fallback = OnlinePlaylist(
      id: '123',
      source: OnlineSource.qq,
      name: '旧歌单',
    );
    final detail = QqPlaylistService.parseDetail(
      {
        'code': 0,
        'cdlist': [
          {
            'dissname': '新歌单',
            'nickname': '创建者',
            'desc': '简介',
            'visitnum': 20000,
            'logo': 'http://cover.example.com/list.jpg',
            'songlist': [
              {
                'id': 7,
                'mid': 'song-mid',
                'title': '歌曲',
                'interval': 180,
                'singer': [
                  {'name': '歌手', 'mid': 'singer-mid'},
                ],
                'album': {'name': '专辑', 'mid': 'album-mid'},
                'file': {
                  'media_mid': 'media-mid',
                  'size_flac': 30000000,
                  'size_320mp3': 8000000,
                },
              },
            ],
          },
        ],
      },
      fallback: fallback,
    );

    expect(detail.playlist.name, '新歌单');
    expect(detail.playlist.coverUri.toString(),
        'https://cover.example.com/list.jpg');
    final track = detail.tracks.single;
    expect(track.id, 'online:tx:song-mid');
    expect(track.artist, '歌手');
    expect(track.duration, const Duration(minutes: 3));
    expect(
        track.availableQualities, [AudioQuality.flac, AudioQuality.high320k]);
    expect(track.extra['mediaMid'], 'media-mid');
  });
}
