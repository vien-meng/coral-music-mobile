import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/song_list/data/migu_playlist_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes Migu playlist tags and nested plaza entries', () {
    final tags = MiguPlaylistService.parseTags({
      'code': '000000',
      'data': [
        {
          'content': [
            {
              'texts': ['流行', 'tag-1'],
            },
          ],
        },
      ],
    });
    final result = MiguPlaylistService.parsePopular(
      {
        'code': '000000',
        'data': {
          'contents': [
            {
              'contents': [
                {
                  'resType': '2021',
                  'resId': 'playlist-1',
                  'txt': '咪咕歌单',
                  'txt2': '歌单简介',
                  'img': 'http://cover.example.com/list.jpg',
                },
              ],
            },
          ],
        },
      },
      page: 1,
    );

    expect(tags.single.name, '流行');
    expect(result.items.single.id, 'playlist-1');
    expect(result.items.single.source, OnlineSource.migu);
    expect(result.items.single.coverUri.toString(),
        'https://cover.example.com/list.jpg');
    expect(result.hasNext, isFalse);
  });

  test('normalizes Migu playlist detail tracks and qualities', () {
    const fallback = OnlinePlaylist(
      id: 'playlist-1',
      source: OnlineSource.migu,
      name: '旧歌单',
    );
    final detail = MiguPlaylistService.parseDetail(
      songs: {
        'code': '000000',
        'data': {
          'totalCount': 1,
          'songList': [
            {
              'songId': 'song-1',
              'songName': '歌曲',
              'singerList': [
                {'name': '歌手'},
              ],
              'album': '专辑',
              'duration': 215,
              'img3': 'http://cover.example.com/song.jpg',
              'audioFormats': [
                {'formatType': 'SQ'},
                {'formatType': 'HQ'},
              ],
              'albumId': 'album-1',
              'copyrightId': 'copyright-1',
            },
          ],
        },
      },
      info: {
        'code': '000000',
        'data': {
          'title': '新歌单',
          'ownerName': '创建者',
          'summary': '简介',
          'imgItem': {'img': 'http://cover.example.com/list.jpg'},
          'opNumItem': {'playNum': 20000},
        },
      },
      fallback: fallback,
    );

    expect(detail.playlist.name, '新歌单');
    expect(detail.playlist.playCount, '2.0万');
    final track = detail.tracks.single;
    expect(track.id, 'online:mg:song-1');
    expect(track.artist, '歌手');
    expect(track.duration, const Duration(seconds: 215));
    expect(
        track.availableQualities, [AudioQuality.flac, AudioQuality.high320k]);
  });
}
