import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../core/response_json.dart';
import '../../../domain/music.dart';
import 'netease_eapi.dart';
import 'online_catalog_service.dart';

Track? neteaseTrackFromSong(Map song) {
  final id = '${song['id'] ?? ''}'.trim();
  final title = '${song['name'] ?? ''}'.trim();
  if (id.isEmpty || title.isEmpty) return null;
  final artists = song['artists'] ?? song['ar'];
  final album = song['album'] ?? song['al'];
  final milliseconds = int.tryParse('${song['duration'] ?? song['dt'] ?? ''}');
  return Track(
    sourceKind: TrackSourceKind.online,
    sourceId: OnlineSource.netease.id,
    sourceTrackId: id,
    title: title,
    artist: artists is List
        ? artists
            .whereType<Map>()
            .map((item) => '${item['name'] ?? ''}')
            .where((name) => name.isNotEmpty)
            .join('、')
        : '',
    album: album is Map ? '${album['name'] ?? ''}' : null,
    duration: milliseconds == null || milliseconds <= 0
        ? null
        : Duration(milliseconds: milliseconds),
    coverUri: neteaseCoverUri(album is Map ? album['picUrl'] : null) ??
        neteaseCoverUri(album is Map ? album['pic'] : null) ??
        neteaseCoverUri(song['picUrl']),
  );
}

Uri? neteaseCoverUri(Object? raw) {
  final uri = Uri.tryParse('$raw'.trim());
  if (uri == null || uri.host.isEmpty) return null;
  return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
}

final class NeteaseCatalogService implements OnlineCatalogService {
  NeteaseCatalogService(this._dio);
  final Dio _dio;
  static const _boards = <LeaderboardBoard>[
    LeaderboardBoard(
        id: 'wy__19723756',
        source: OnlineSource.netease,
        name: '飙升榜',
        remoteId: '19723756'),
    LeaderboardBoard(
        id: 'wy__3778678',
        source: OnlineSource.netease,
        name: '热歌榜',
        remoteId: '3778678'),
    LeaderboardBoard(
        id: 'wy__3779629',
        source: OnlineSource.netease,
        name: '新歌榜',
        remoteId: '3779629'),
    LeaderboardBoard(
        id: 'wy__2884035',
        source: OnlineSource.netease,
        name: '原创榜',
        remoteId: '2884035'),
  ];

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(
      OnlineSource source) async {
    if (source != OnlineSource.netease) {
      throw _unsupported('排行榜');
    }
    return _boards;
  }

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
      OnlineSource source, String boardId, int page) async {
    final board = _boards.where((item) => item.id == boardId).firstOrNull;
    if (source != OnlineSource.netease || page != 1 || board == null) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云榜单请求参数无效');
    }
    try {
      final response = await _dio.getUri<Object?>(
          Uri.https('music.163.com', '/api/v6/playlist/detail',
              {'id': board.remoteId, 'n': '1000'}),
          options: Options(headers: const {
            'Referer': 'https://music.163.com/',
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
                'Chrome/60.0.3112.90 Safari/537.36',
          }));
      return _parse(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
          code: AppFailureCode.invalidData,
          message: '网易云榜单数据解析失败',
          diagnostic: error.runtimeType.toString());
    }
  }

  @override
  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  ) async {
    final keyword = query.trim();
    if (source != OnlineSource.netease || keyword.isEmpty || page < 1) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云搜索请求参数无效');
    }
    try {
      final response = await _dio.postUri<Object?>(
        Uri.https('interface3.music.163.com', '/eapi/search/song/list/page'),
        data: {
          'params': neteaseEapiParams('/api/search/song/list/page', {
            'keyword': keyword,
            'needCorrect': '1',
            'channel': 'typing',
            'offset': (page - 1) * 30,
            'scene': 'normal',
            'total': page == 1,
            'limit': 30,
          }),
        },
        options: Options(headers: const {
          'Referer': 'https://music.163.com/',
          'Origin': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
              'Chrome/60.0.3112.90 Safari/537.36',
        }, contentType: Headers.formUrlEncodedContentType),
      );
      return _parseEapiSearch(response.data, page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
          code: AppFailureCode.invalidData,
          message: '网易云搜索数据解析失败',
          diagnostic: error.runtimeType.toString());
    }
  }

  static PageResult<Track> _parse(Object? raw) {
    final playlist = decodeJsonMap(raw)['playlist'];
    final songs = playlist is Map ? playlist['tracks'] : null;
    if (songs is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云榜单歌曲缺失');
    }
    final tracks = <Track>[];
    for (final song in songs.whereType<Map>()) {
      final track = neteaseTrackFromSong(song);
      if (track != null) tracks.add(track);
    }
    final withCover = tracks.where((t) => t.coverUri != null).length;
    debugPrint('[NeteaseBoard] songs=${songs.length} tracks=${tracks.length} withCover=$withCover');
    return PageResult(
        items: tracks, page: 1, pageSize: tracks.length, total: tracks.length);
  }

  static PageResult<Track> _parseEapiSearch(Object? raw, int page) {
    final data = raw is Map ? raw['data'] : null;
    final resources = data is Map ? data['resources'] : null;
    if (resources is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云搜索歌曲缺失');
    }
    return _parseSearch({
      'result': {
        'songs': [
          for (final resource in resources.whereType<Map>())
            if (resource['baseInfo'] case {'simpleSongData': Map song})
              {
                'id': song['id'],
                'name': song['name'],
                'artists': song['ar'],
                'album': song['al'],
                'duration': song['dt'],
                'picUrl': _resourceCover(resource),
              },
        ],
        'songCount': data['totalCount'],
      },
    }, page);
  }

  static Object? _resourceCover(Map resource) {
    final uiElement = resource['uiElement'];
    final image = uiElement is Map ? uiElement['image'] : null;
    return image is Map
        ? image['imageUrl'] ?? image['url']
        : image ?? resource['picUrl'];
  }

  static PageResult<Track> _parseSearch(Object? raw, int page) {
    final result = raw is Map ? raw['result'] : null;
    final songs = result is Map ? result['songs'] : null;
    if (songs is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云搜索歌曲缺失');
    }
    final tracks = <Track>[];
    for (final song in songs.whereType<Map>()) {
      final track = neteaseTrackFromSong(song);
      if (track != null) tracks.add(track);
    }
    final total = int.tryParse('${result['songCount'] ?? ''}') ?? tracks.length;
    return PageResult(items: tracks, page: page, pageSize: 30, total: total);
  }

  AppFailure _unsupported(String feature) => AppFailure(
      code: AppFailureCode.invalidData, message: '网易云音乐暂未接入$feature');
}
