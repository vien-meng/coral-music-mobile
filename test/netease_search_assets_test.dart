import 'dart:convert';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/netease_catalog_service.dart';
import 'package:coral_music_mobile/features/song_list/data/netease_playlist_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes NetEase song artwork to HTTPS', () {
    final track = neteaseTrackFromSong({
      'id': 1,
      'name': '歌曲',
      'ar': const [],
      'al': {
        'name': '专辑',
        'picUrl': 'http://p1.music.126.net/cover.jpg',
      },
      'dt': 1000,
    });

    expect(track?.coverUri.toString(), 'https://p1.music.126.net/cover.jpg');
  });

  test('keeps NetEase song artwork when the endpoint uses pic', () {
    final track = neteaseTrackFromSong({
      'id': 1,
      'name': '歌曲',
      'artists': const [],
      'album': {'name': '专辑', 'pic': 'http://p1.music.126.net/cover.jpg'},
    });

    expect(track?.coverUri.toString(), 'https://p1.music.126.net/cover.jpg');
  });

  test('falls back when NetEase returns an empty preferred artwork field', () {
    final track = neteaseTrackFromSong({
      'id': 1,
      'name': '歌曲',
      'ar': const [],
      'al': {
        'name': '专辑',
        'picUrl': '',
        'pic': 'http://p1.music.126.net/cover.jpg',
      },
    });

    expect(track?.coverUri.toString(), 'https://p1.music.126.net/cover.jpg');
  });

  test('searches NetEase playlists from its text JSON response', () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response<String>(
          requestOptions: options,
          data: jsonEncode({
            'result': {
              'playlistCount': 1,
              'playlists': [
                {
                  'id': 1,
                  'name': '周杰伦歌单',
                  'coverImgUrl': 'http://p1.music.126.net/list.jpg',
                  'creator': {'nickname': '歌单作者'},
                  'trackCount': 12,
                  'playCount': 12000,
                },
              ],
            },
          }),
        )),
      ));

    final result = await NeteasePlaylistService(dio).searchPlaylists('周杰伦', 1);

    expect(result.items.single.source, OnlineSource.netease);
    expect(result.items.single.coverUri.toString(),
        'https://p1.music.126.net/list.jpg');
  });

  test('loads NetEase recommended playlists', () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response<String>(
          requestOptions: options,
          data: jsonEncode({
            'result': [
              {
                'id': 1,
                'name': '推荐歌单',
                'picUrl': 'http://p1.music.126.net/list.jpg',
                'trackCount': 12,
                'playCount': 12000,
              },
            ],
          }),
        )),
      ));

    final result = await NeteasePlaylistService(dio).getPopularPlaylists(1);

    expect(result.items.single.name, '推荐歌单');
    expect(result.items.single.coverUri.toString(),
        'https://p1.music.126.net/list.jpg');
  });

  test('falls back to NetEase picUrl when coverImgUrl is empty', () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response<Object?>(
          requestOptions: options,
          data: {
            'result': [
              {
                'id': 1,
                'name': '推荐歌单',
                'coverImgUrl': '',
                'picUrl': 'http://p1.music.126.net/list.jpg',
              },
            ],
          },
        )),
      ));

    final result = await NeteasePlaylistService(dio).getPopularPlaylists(1);

    expect(result.items.single.coverUri.toString(),
        'https://p1.music.126.net/list.jpg');
  });

  test('parses a text JSON NetEase leaderboard response', () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response<String>(
          requestOptions: options,
          data: jsonEncode({
            'playlist': {
              'tracks': [
                {
                  'id': 1,
                  'name': '榜单歌曲',
                  'ar': const [],
                  'al': const {'name': '榜单专辑'},
                  'dt': 1000,
                },
              ],
            },
          }),
        )),
      ));

    final boards = await NeteaseCatalogService(dio)
        .getLeaderboardBoards(OnlineSource.netease);
    final result = await NeteaseCatalogService(dio)
        .getLeaderboardDetail(OnlineSource.netease, boards.first.id, 1);

    expect(result.items.single.title, '榜单歌曲');
  });

  test('keeps NetEase EAPI resource-card artwork in search results', () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response<Object?>(
          requestOptions: options,
          data: {
            'data': {
              'totalCount': 1,
              'resources': [
                {
                  'baseInfo': {
                    'simpleSongData': {
                      'id': 1,
                      'name': '搜索歌曲',
                      'ar': const [],
                      'al': const {'name': '搜索专辑'},
                      'dt': 1000,
                    },
                  },
                  'uiElement': {
                    'image': {
                      'imageUrl': 'http://p1.music.126.net/search.jpg',
                    },
                  },
                },
              ],
            },
          },
        )),
      ));

    final result = await NeteaseCatalogService(dio)
        .searchTracks(OnlineSource.netease, '搜索', 1);

    expect(result.items.single.coverUri.toString(),
        'https://p1.music.126.net/search.jpg');
  });
}
