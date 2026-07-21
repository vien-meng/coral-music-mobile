import 'dart:convert';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/song_list/data/kuwo_playlist_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves non-8 digest nodes before loading Kuwo playlist detail',
      () async {
    final requests = <Uri>[];
    final service = KuwoPlaylistService(_fakeDio(requests));

    await service.getPlaylistDetail(const OnlinePlaylist(
      id: 'digest-5__123',
      source: OnlineSource.kuwo,
      name: '测试歌单',
    ));

    expect(requests, hasLength(2));
    expect(requests.first.host, 'qukudata.kuwo.cn');
    expect(requests.first.queryParameters['node'], '123');
    expect(requests.last.queryParameters['pid'], '456');
  });

  test('loads digest-8 Kuwo playlist detail directly', () async {
    final requests = <Uri>[];
    final service = KuwoPlaylistService(_fakeDio(requests));

    await service.getPlaylistDetail(const OnlinePlaylist(
      id: 'digest-8__123',
      source: OnlineSource.kuwo,
      name: '测试歌单',
    ));

    expect(requests, hasLength(1));
    expect(requests.single.host, 'nplserver.kuwo.cn');
    expect(requests.single.queryParameters['pid'], '123');
  });

  test('requests the Kuwo playlist search result mode', () async {
    final requests = <Uri>[];
    final service = KuwoPlaylistService(_fakeDio(
      requests,
      data: (uri) => uri.host == 'search.kuwo.cn'
          ? {
              'TOTAL': '1',
              'abslist': [
                {
                  'playlistid': 'playlist-1',
                  'name': '搜索歌单',
                  'nickname': '创建者',
                  'pic': 'http://cover.example.com/list.jpg',
                },
              ],
            }
          : {
              'result': 'ok',
              'musiclist': <Object?>[],
            },
    ));

    final result = await service.searchPlaylists('关键词', 1);

    expect(requests.single.queryParameters['needliveshow'], '0');
    expect(result.items.single.name, '搜索歌单');
  });

  test('falls back from empty Kuwo cover fields to album artwork', () async {
    final service = KuwoPlaylistService(_fakeDio(
      <Uri>[],
      data: (_) => {
        'result': 'ok',
        'pic': '',
        'musiclist': [
          {
            'id': 'song-1',
            'name': '歌曲',
            'pic': '',
            'albumPic': 'http://cover.example.com/song.jpg',
          },
        ],
      },
    ));

    final detail = await service.getPlaylistDetail(const OnlinePlaylist(
      id: 'digest-8__123',
      source: OnlineSource.kuwo,
      name: '测试歌单',
    ));

    expect(detail.tracks.single.coverUri.toString(),
        'https://cover.example.com/song.jpg');
    expect(detail.playlist.coverUri, detail.tracks.single.coverUri);
  });

  test('keeps the plaza cover and resolves missing detail track covers',
      () async {
    final requests = <Uri>[];
    final service = KuwoPlaylistService(_fakeDio(
      requests,
      data: (uri) {
        if (uri.host == 'search.kuwo.cn') {
          final second = uri.queryParameters['all']!.contains('歌曲二');
          return jsonEncode({
            'abslist': [
              {
                'MUSICRID': second ? 'MUSIC_song-2' : 'MUSIC_song-1',
                'web_albumpic_short':
                    second ? '4/76/1414274524.jpg' : '3/75/1414274523.jpg',
              },
            ],
          });
        }
        return {
          'result': 'ok',
          'pic': 'https://invalid.example.com/detail.jpg',
          'musiclist': [
            {
              'id': 'song-1',
              'name': '歌曲一',
              'artist': '歌手',
            },
            {
              'id': 'song-2',
              'name': '歌曲二',
              'artist': '歌手',
            },
          ],
        };
      },
    ));

    final detail = await service.getPlaylistDetail(OnlinePlaylist(
      id: 'digest-8__123',
      source: OnlineSource.kuwo,
      name: '测试歌单',
      coverUri: Uri.parse('https://cover.example.com/plaza.jpg'),
    ));

    expect(detail.playlist.coverUri.toString(),
        'https://cover.example.com/plaza.jpg');
    final tracks = await Future.wait(
      detail.tracks.map(service.resolveTrackArtwork),
    );
    expect(requests.where((uri) => uri.host == 'search.kuwo.cn'), hasLength(2));
    expect(tracks.map((track) => track.coverUri.toString()), [
      'https://img3.kuwo.cn/star/albumcover/500/3/75/1414274523.jpg',
      'https://img3.kuwo.cn/star/albumcover/500/4/76/1414274524.jpg',
    ]);
  });

  test('uses the playlist artwork when a missing track has no search cover',
      () async {
    final service = KuwoPlaylistService(_fakeDio(
      <Uri>[],
      data: (_) => jsonEncode({'abslist': []}),
    ));

    final track = await service.resolveTrackArtwork(
      const Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'kw',
        sourceTrackId: 'song-1',
        title: '歌曲',
        artist: '歌手',
      ),
      fallbackCover: Uri.parse('https://cover.example.com/playlist.jpg'),
    );

    expect(track.coverUri.toString(), 'https://cover.example.com/playlist.jpg');
  });
}

Dio _fakeDio(List<Uri> requests, {Object? Function(Uri uri)? data}) => Dio()
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      requests.add(options.uri);
      handler.resolve(Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: data?.call(options.uri) ??
            (options.uri.host == 'qukudata.kuwo.cn'
                ? {
                    'child': [
                      {'sourceid': 456},
                    ],
                  }
                : {
                    'result': 'ok',
                    'musiclist': <Object?>[],
                    'title': '测试歌单',
                    'total': 0,
                  }),
      ));
    },
  ));
