import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import 'online_catalog_service.dart';

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
      final response = await _dio.getUri<Object?>(Uri.https('music.163.com',
          '/api/playlist/detail', {'id': board.remoteId, 'n': '1000'}));
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
      final response = await _dio.getUri<Object?>(
        Uri.https('music.163.com', '/api/search/get/web', {
          's': keyword,
          'type': '1',
          'offset': '${(page - 1) * 30}',
          'limit': '30',
        }),
      );
      return _parseSearch(response.data, page);
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
    final playlist = raw is Map ? raw['playlist'] : null;
    final songs = playlist is Map ? playlist['tracks'] : null;
    if (songs is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '网易云榜单歌曲缺失');
    }
    final tracks = <Track>[];
    for (final song in songs.whereType<Map>()) {
      final id = '${song['id'] ?? ''}';
      final title = '${song['name'] ?? ''}'.trim();
      if (id.isEmpty || title.isEmpty) continue;
      final artists = song['ar'];
      final album = song['al'];
      final milliseconds = int.tryParse('${song['dt'] ?? ''}');
      tracks.add(Track(
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
          coverUri:
              album is Map ? Uri.tryParse('${album['picUrl'] ?? ''}') : null));
    }
    return PageResult(
        items: tracks, page: 1, pageSize: tracks.length, total: tracks.length);
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
      final id = '${song['id'] ?? ''}';
      final title = '${song['name'] ?? ''}'.trim();
      if (id.isEmpty || title.isEmpty) continue;
      final artists = song['artists'];
      final album = song['album'];
      final milliseconds = int.tryParse('${song['duration'] ?? ''}');
      tracks.add(Track(
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
        coverUri:
            album is Map ? Uri.tryParse('${album['picUrl'] ?? ''}') : null,
      ));
    }
    final total = int.tryParse('${result['songCount'] ?? ''}') ?? tracks.length;
    return PageResult(items: tracks, page: page, pageSize: 30, total: total);
  }

  AppFailure _unsupported(String feature) => AppFailure(
      code: AppFailureCode.invalidData, message: '网易云音乐暂未接入$feature');
}
