import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../core/response_json.dart';
import '../../../domain/music.dart';
import '../../leaderboard/data/qq_track_support.dart';
import 'kuwo_playlist_service.dart';

final class QqPlaylistService implements PlaylistCatalogService {
  QqPlaylistService(this._dio);

  final Dio _dio;
  static const _pageSize = 30;

  @override
  Future<List<PlaylistTag>> getTags() => Future.value(const <PlaylistTag>[]);

  @override
  Future<PageResult<OnlinePlaylist>> getPopularPlaylists(
    int page, {
    String? tagId,
    String sortId = 'hot',
  }) async {
    if (page < 1) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐歌单页码无效',
      );
    }
    const uri = 'https://u.y.qq.com/cgi-bin/musicu.fcg';
    final payload = {
      'comm': {'cv': 1602, 'ct': 20, 'format': 'json'},
      'playlist': {
        'module': 'playlist.PlayListPlazaServer',
        'method': 'get_playlist_by_tag',
        'param': {
          'id': int.tryParse(tagId ?? '') ?? 10000000,
          'sin': _pageSize * (page - 1),
          'size': _pageSize,
          'order': sortId == 'new' ? 2 : 5,
          'cur_page': page,
        },
      },
    };
    try {
      final response = await _dio.post<String>(
        uri,
        data: jsonEncode(payload),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
        ),
      );
      final raw = response.data;
      if (raw == null || raw.isEmpty) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: 'QQ 音乐歌单响应为空',
        );
      }
      return parsePopular(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
        page: page,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐歌单数据解析失败',
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
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐歌单搜索参数无效',
      );
    }
    final uri =
        Uri.https('c.y.qq.com', '/soso/fcgi-bin/client_music_search_songlist', {
      'page_no': '${page - 1}',
      'num_per_page': '$_pageSize',
      'format': 'json',
      'query': keyword,
      'remoteplace': 'txt.yqq.playlist',
      'inCharset': 'utf8',
      'outCharset': 'utf-8',
    });
    try {
      final response = await _dio.getUri<Object?>(uri,
          options: Options(headers: {
            'Referer': 'https://y.qq.com/',
            'User-Agent':
                'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)',
          }));
      return parseSearch(response.data, page: page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐歌单搜索数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PlaylistDetail> getPlaylistDetail(OnlinePlaylist playlist) async {
    if (playlist.source != OnlineSource.qq || playlist.id.trim().isEmpty) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐歌单标识无效',
      );
    }
    final uri = Uri.https(
        'c.y.qq.com', '/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg', {
      'type': '1',
      'json': '1',
      'utf8': '1',
      'onlysong': '0',
      'new_format': '1',
      'disstid': playlist.id,
      'loginUin': '0',
      'hostUin': '0',
      'format': 'json',
      'inCharset': 'utf8',
      'outCharset': 'utf-8',
      'notice': '0',
      'platform': 'yqq.json',
      'needNewCode': '0',
    });
    try {
      final response = await _dio.getUri<Object?>(uri,
          options: Options(
            headers: {
              'Origin': 'https://y.qq.com',
              'Referer': 'https://y.qq.com/n/ryqq/playlist/${playlist.id}',
            },
          ));
      return parseDetail(response.data, fallback: playlist);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐歌单详情数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  static PageResult<OnlinePlaylist> parsePopular(
    Map<String, Object?> response, {
    required int page,
  }) {
    final playlist = response['playlist'];
    final data = playlist is Map ? playlist['data'] : null;
    final items = data is Map ? data['v_playlist'] : null;
    if (response['code'] != 0 ||
        playlist is! Map ||
        playlist['code'] != 0 ||
        items is! List) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐歌单广场数据格式异常',
      );
    }
    final playlists = <OnlinePlaylist>[];
    for (final item in items.whereType<Map>()) {
      final id = '${item['tid'] ?? ''}'.trim();
      final name = '${item['title'] ?? ''}'.trim();
      if (id.isEmpty || name.isEmpty) continue;
      final creator = item['creator_info'];
      playlists.add(OnlinePlaylist(
        id: id,
        source: OnlineSource.qq,
        name: name,
        author: creator is Map ? '${creator['nick'] ?? ''}'.trim() : '',
        description: _description(item['desc']),
        trackCount: (item['song_ids'] as List?)?.length ?? 0,
        playCount: _formatCount(item['access_num']),
        coverUri: _httpsUri(item['cover_url_medium']),
      ));
    }
    return PageResult(
      items: playlists,
      page: page,
      pageSize: _pageSize,
      total: int.tryParse('${data['total'] ?? ''}') ?? playlists.length,
    );
  }

  static PageResult<OnlinePlaylist> parseSearch(
    Object? raw, {
    required int page,
  }) {
    final response = decodeJsonMap(raw);
    final data = response['data'];
    final items = data is Map ? data['list'] : null;
    if ('${response['code']}' != '0' || data is! Map || items is! List) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐歌单搜索数据格式异常',
      );
    }
    final playlists = <OnlinePlaylist>[];
    final ids = <String>{};
    for (final item in items.whereType<Map>()) {
      final id = '${item['dissid'] ?? ''}'.trim();
      final name = '${item['dissname'] ?? ''}'.trim();
      if (id.isEmpty || name.isEmpty || !ids.add(id)) continue;
      final creator = item['creator'];
      playlists.add(OnlinePlaylist(
        id: id,
        source: OnlineSource.qq,
        name: name,
        author: creator is Map ? '${creator['name'] ?? ''}'.trim() : '',
        description: _description(item['introduction']),
        trackCount: int.tryParse('${item['song_count'] ?? ''}') ?? 0,
        playCount: _formatCount(item['listennum']),
        coverUri: _httpsUri(item['imgurl']),
      ));
    }
    return PageResult(
      items: playlists,
      page: page,
      pageSize: _pageSize,
      total: int.tryParse('${data['sum'] ?? ''}') ?? playlists.length,
    );
  }

  static PlaylistDetail parseDetail(
    Object? raw, {
    required OnlinePlaylist fallback,
  }) {
    final response = decodeJsonMap(raw);
    final list = response['cdlist'];
    final detail = list is List && list.isNotEmpty && list.first is Map
        ? list.first as Map
        : null;
    final songs = detail?['songlist'];
    if ('${response['code']}' != '0' || detail == null || songs is! List) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐歌单详情格式异常',
      );
    }
    final tracks = <Track>[];
    final ids = <String>{};
    for (final song in songs.whereType<Map>()) {
      final mid = '${song['mid'] ?? ''}'.trim();
      final title = '${song['title'] ?? ''}'.trim();
      if (mid.isEmpty || title.isEmpty || !ids.add(mid)) continue;
      final album = song['album'];
      final file = song['file'];
      final albumMap = album is Map ? album : const <Object?, Object?>{};
      final fileMap = file is Map ? file : const <Object?, Object?>{};
      final singer = song['singer'];
      final singerList =
          singer is List ? singer.whereType<Map>().toList() : const <Map>[];
      final albumMid = '${albumMap['mid'] ?? ''}'.trim();
      final singerMid = singerList
          .map((item) => '${item['mid'] ?? ''}'.trim())
          .firstWhere((item) => item.isNotEmpty, orElse: () => '');
      tracks.add(Track(
        sourceKind: TrackSourceKind.online,
        sourceId: OnlineSource.qq.id,
        sourceTrackId: mid,
        title: title,
        artist: singerList
            .map((item) => '${item['name'] ?? ''}'.trim())
            .where((item) => item.isNotEmpty)
            .join('、'),
        album: '${albumMap['name'] ?? ''}'.trim(),
        duration: _duration(song['interval']),
        coverUri: _trackCover(albumMid, singerMid),
        availableQualities: _qualities(fileMap),
        extra: {
          'songId': song['id'],
          'albumMid': albumMid,
          'mediaMid': fileMap['media_mid'],
          'qualityMeta': qqQualityMeta(fileMap),
        },
      ));
    }
    return PlaylistDetail(
      playlist: OnlinePlaylist(
        id: fallback.id,
        source: OnlineSource.qq,
        name: '${detail['dissname'] ?? fallback.name}'.trim(),
        author: '${detail['nickname'] ?? fallback.author}'.trim(),
        description: _description(detail['desc']).isEmpty
            ? fallback.description
            : _description(detail['desc']),
        trackCount: tracks.length,
        playCount: _formatCount(detail['visitnum']),
        coverUri: _httpsUri(detail['logo']) ?? fallback.coverUri,
      ),
      tracks: tracks,
    );
  }

  static List<AudioQuality> _qualities(Map<Object?, Object?> file) =>
      qqAudioQualities(file);

  static Duration? _duration(Object? value) {
    final seconds = int.tryParse('$value');
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }

  static Uri? _trackCover(String albumMid, String singerMid) {
    final type = albumMid.isNotEmpty ? 'T002' : 'T001';
    final id = albumMid.isNotEmpty ? albumMid : singerMid;
    return id.isEmpty
        ? null
        : Uri.parse(
            'https://y.gtimg.cn/music/photo_new/${type}R500x500M000$id.jpg');
  }

  static Uri? _httpsUri(Object? value) {
    final uri = Uri.tryParse('$value'.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }

  static String _description(Object? value) =>
      '$value'.trim().replaceAll('<br>', '\n');

  static String _formatCount(Object? value) {
    final count = int.tryParse('$value') ?? 0;
    if (count >= 100000000) return '${(count / 10000000).toStringAsFixed(1)}亿';
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return count == 0 ? '' : '$count';
  }
}
