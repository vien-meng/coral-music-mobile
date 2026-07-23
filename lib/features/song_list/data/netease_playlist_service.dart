import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../core/response_json.dart';
import '../../../domain/music.dart';
import '../../leaderboard/data/netease_catalog_service.dart';
import 'kuwo_playlist_service.dart';

final class NeteasePlaylistService implements PlaylistCatalogService {
  NeteasePlaylistService(this._dio);

  final Dio _dio;
  static const _pageSize = 30;
  static const _headers = {'Referer': 'https://music.163.com/'};

  @override
  Future<List<PlaylistTag>> getTags() async => const [];

  @override
  Future<PageResult<OnlinePlaylist>> getPopularPlaylists(
    int page, {
    String? tagId,
    String sortId = 'hot',
  }) async {
    if (page != 1) {
      return const PageResult(
          items: [], page: 1, pageSize: _pageSize, total: _pageSize);
    }
    try {
      final response = await _dio.getUri<Object?>(
        Uri.https('music.163.com', '/api/personalized/playlist', {
          'limit': '$_pageSize',
        }),
        options: Options(headers: _headers),
      );
      final items = decodeJsonMap(response.data)['result'];
      if (items is! List) {
        throw const AppFailure(
            code: AppFailureCode.invalidData, message: '网易云推荐歌单响应异常');
      }
      final playlists = items
          .whereType<Map>()
          .map(_playlist)
          .whereType<OnlinePlaylist>()
          .toList(growable: false);
      return PageResult(
        items: playlists,
        page: page,
        pageSize: _pageSize,
        total: playlists.length,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '网易云推荐歌单数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PageResult<OnlinePlaylist>> searchPlaylists(
    String query,
    int page,
  ) async {
    final keyword = query.trim();
    if (keyword.isEmpty || page < 1) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云歌单搜索参数无效');
    }
    try {
      final response = await _dio.getUri<Object?>(
        Uri.https('music.163.com', '/api/search/get/web', {
          's': keyword,
          'type': '1000',
          'offset': '${(page - 1) * _pageSize}',
          'total': '${page == 1}',
          'limit': '$_pageSize',
        }),
        options: Options(headers: _headers),
      );
      return _parseSearch(response.data, page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '网易云歌单搜索数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PlaylistDetail> getPlaylistDetail(OnlinePlaylist playlist) async {
    if (playlist.source != OnlineSource.netease || playlist.id.isEmpty) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云歌单标识无效');
    }
    try {
      final response = await _dio.getUri<Object?>(
        Uri.https('music.163.com', '/api/v6/playlist/detail', {
          'id': playlist.id,
          'n': '1000',
        }),
        options: Options(headers: _headers),
      );
      return _parseDetail(response.data, playlist);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '网易云歌单详情数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  static PageResult<OnlinePlaylist> _parseSearch(Object? raw, int page) {
    final result = decodeJsonMap(raw)['result'] as Map?;
    final items = result?['playlists'];
    if (result == null || items is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云歌单搜索响应异常');
    }
    final playlists = items
        .whereType<Map>()
        .map(_playlist)
        .whereType<OnlinePlaylist>()
        .toList(growable: false);
    return PageResult(
      items: playlists,
      page: page,
      pageSize: _pageSize,
      total:
          int.tryParse('${result['playlistCount'] ?? ''}') ?? playlists.length,
    );
  }

  static PlaylistDetail _parseDetail(Object? raw, OnlinePlaylist fallback) {
    final item = decodeJsonMap(raw)['playlist'];
    final tracks = item is Map ? item['tracks'] : null;
    if (item is! Map || tracks is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云歌单详情响应异常');
    }
    final playlist = _playlist(item) ?? fallback;
    return PlaylistDetail(
      playlist: playlist,
      tracks: tracks
          .whereType<Map>()
          .map(neteaseTrackFromSong)
          .whereType<Track>()
          .toList(growable: false),
    );
  }

  static OnlinePlaylist? _playlist(Map item) {
    final id = '${item['id'] ?? ''}'.trim();
    final name = '${item['name'] ?? ''}'.trim();
    if (id.isEmpty || name.isEmpty) return null;
    final creator = item['creator'];
    return OnlinePlaylist(
      id: id,
      source: OnlineSource.netease,
      name: name,
      author: creator is Map ? '${creator['nickname'] ?? ''}'.trim() : '',
      description: '${item['description'] ?? ''}'.trim(),
      trackCount: int.tryParse('${item['trackCount'] ?? ''}') ?? 0,
      playCount: _formatCount(item['playCount']),
      coverUri: neteaseCoverUri(item['coverImgUrl']) ??
          neteaseCoverUri(item['picUrl']),
    );
  }

  static String _formatCount(Object? value) {
    final count = int.tryParse('$value') ?? 0;
    if (count >= 100000000) return '${(count / 10000000).toStringAsFixed(1)}亿';
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return count == 0 ? '' : '$count';
  }
}
