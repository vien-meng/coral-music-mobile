import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import '../../leaderboard/data/kuwo_leaderboard_parser.dart';

final class PlaylistTag {
  const PlaylistTag({required this.id, required this.name});

  final String id;
  final String name;
}

final class KuwoPlaylistService {
  KuwoPlaylistService(this._dio);

  final Dio _dio;
  static const _pageSize = 30;

  Future<List<PlaylistTag>> getTags() async {
    final uri =
        Uri.https('wapi.kuwo.cn', '/api/pc/classify/playlist/getTagList', {
      'cmd': 'rcm_keyword_playlist',
      'user': '0',
      'prod': 'kwplayer_pc_9.0.5.0',
      'vipver': '9.0.5.0',
      'source': 'kwplayer_pc_9.0.5.0',
      'loginUid': '0',
      'loginSid': '0',
      'appUid': '76039576',
    });
    try {
      final response = await _dio.getUri<Object?>(uri);
      return _parseTags(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
          code: AppFailureCode.invalidData,
          message: '歌单标签数据解析失败',
          diagnostic: error.runtimeType.toString());
    }
  }

  Future<PageResult<OnlinePlaylist>> getPopularPlaylists(
    int page, {
    String? tagId,
    String sortId = 'hot',
  }) async {
    if (page < 1) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '歌单页码无效',
      );
    }
    final tagParts = tagId?.split('-');
    final uri = Uri.https(
      'wapi.kuwo.cn',
      tagParts?.length == 2
          ? '/api/pc/classify/playlist/getTagPlayList'
          : '/api/pc/classify/playlist/getRcmPlayList',
      {
        'loginUid': '0',
        'loginSid': '0',
        'appUid': '76039576',
        'pn': '$page',
        'rn': '$_pageSize',
        'order': sortId,
        if (tagParts?.length == 2) 'id': tagParts!.first,
      },
    );
    try {
      final response = await _dio.getUri<Object?>(uri);
      return _parsePopular(response.data, page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '歌单广场数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  Future<PageResult<OnlinePlaylist>> searchPlaylists(
    String query,
    int page,
  ) async {
    final keyword = query.trim();
    if (keyword.isEmpty || page < 1) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '歌单搜索请求参数无效');
    }
    final uri = Uri.https('search.kuwo.cn', '/r.s', {
      'all': keyword,
      'pn': '${page - 1}',
      'rn': '30',
      'rformat': 'json',
      'encoding': 'utf8',
      'ver': 'mbox',
      'vipver': 'MUSIC_8.7.7.0_BCS37',
      'plat': 'pc',
      'devid': '28156413',
      'ft': 'playlist',
      'pay': '0',
    });
    try {
      final response = await _dio.getUri<Object?>(uri);
      return _parseSearch(response.data, page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
          code: AppFailureCode.invalidData,
          message: '歌单搜索数据解析失败',
          diagnostic: error.runtimeType.toString());
    }
  }

  static List<PlaylistTag> _parseTags(Object? raw) {
    final response = _map(raw);
    final groups = response['data'];
    if (response['code'] != 200 || groups is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '歌单标签响应异常');
    }
    final tags = <PlaylistTag>[];
    for (final group in groups.whereType<Map>()) {
      final items = group['data'];
      if (items is! List) continue;
      for (final item in items.whereType<Map>()) {
        if ('${item['digest'] ?? ''}' != '10000') continue;
        final id = '${item['id'] ?? ''}'.trim();
        final name = '${item['name'] ?? ''}'.trim();
        if (id.isNotEmpty && name.isNotEmpty) {
          tags.add(PlaylistTag(id: '$id-10000', name: name));
        }
      }
    }
    return tags;
  }

  Future<PlaylistDetail> getPlaylistDetail(OnlinePlaylist playlist) async {
    final playlistId = playlist.id.split('__').last;
    if (playlistId.isEmpty) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '歌单标识无效',
      );
    }
    final uri = Uri.https('nplserver.kuwo.cn', '/pl.svc', {
      'op': 'getlistinfo',
      'pid': playlistId,
      'pn': '0',
      'rn': '1000',
      'encode': 'utf8',
      'keyset': 'pl2012',
      'identity': 'kuwo',
      'pcmp4': '1',
      'vipver': 'MUSIC_9.0.5.0_W1',
      'newver': '1',
    });
    try {
      final response = await _dio.getUri<Object?>(uri);
      return _parseDetail(response.data, playlist);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '歌单详情数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  static PageResult<OnlinePlaylist> _parsePopular(Object? raw, int page) {
    final response = _map(raw);
    final data = _map(response['data']);
    final items = data['data'];
    if (response['code'] != 200 || items is! List) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '歌单广场响应异常',
      );
    }
    final playlists = <OnlinePlaylist>[];
    for (final rawItem in items) {
      final item = _map(rawItem);
      final id = '${item['id'] ?? ''}'.trim();
      final digest = '${item['digest'] ?? ''}'.trim();
      final name =
          KuwoLeaderboardParser.decodeText('${item['name'] ?? ''}').trim();
      if (id.isEmpty || digest.isEmpty || name.isEmpty) continue;
      playlists.add(
        OnlinePlaylist(
          id: 'digest-${digest}__$id',
          source: OnlineSource.kuwo,
          name: name,
          author:
              KuwoLeaderboardParser.decodeText('${item['uname'] ?? ''}').trim(),
          description:
              KuwoLeaderboardParser.decodeText('${item['desc'] ?? ''}').trim(),
          trackCount: int.tryParse('${item['total'] ?? ''}') ?? 0,
          playCount: _formatCount(item['listencnt']),
          coverUri: _httpsUri('${item['img'] ?? ''}'),
        ),
      );
    }
    return PageResult(
      items: playlists,
      page: int.tryParse('${data['pn'] ?? ''}') ?? page,
      pageSize: int.tryParse('${data['rn'] ?? ''}') ?? _pageSize,
      total: int.tryParse('${data['total'] ?? ''}') ?? playlists.length,
    );
  }

  static PlaylistDetail _parseDetail(Object? raw, OnlinePlaylist fallback) {
    final response = _map(raw);
    final items = response['musiclist'];
    if (response['result'] != 'ok' || items is! List) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '歌单详情响应异常',
      );
    }
    final tracks = <Track>[];
    final ids = <String>{};
    for (final rawItem in items) {
      final item = _map(rawItem);
      final id = '${item['id'] ?? ''}'.trim();
      final title =
          KuwoLeaderboardParser.decodeText('${item['name'] ?? ''}').trim();
      if (id.isEmpty || title.isEmpty || !ids.add(id)) continue;
      final duration = int.tryParse('${item['duration'] ?? ''}');
      tracks.add(
        Track(
          sourceKind: TrackSourceKind.online,
          sourceId: OnlineSource.kuwo.id,
          sourceTrackId: id,
          title: title,
          artist: KuwoLeaderboardParser.decodeText('${item['artist'] ?? ''}')
              .replaceAll('&', '、')
              .trim(),
          album:
              KuwoLeaderboardParser.decodeText('${item['album'] ?? ''}').trim(),
          duration: duration == null ? null : Duration(seconds: duration),
          availableQualities: KuwoLeaderboardParser.parseQualities(
            '${item['N_MINFO'] ?? item['n_minfo'] ?? ''}',
          ),
          extra: {'albumId': item['albumid']},
        ),
      );
    }
    return PlaylistDetail(
      playlist: OnlinePlaylist(
        id: fallback.id,
        source: fallback.source,
        name: KuwoLeaderboardParser.decodeText(
                '${response['title'] ?? fallback.name}')
            .trim(),
        author: KuwoLeaderboardParser.decodeText(
                '${response['uname'] ?? fallback.author}')
            .trim(),
        description: KuwoLeaderboardParser.decodeText(
                '${response['info'] ?? fallback.description}')
            .trim(),
        trackCount: int.tryParse('${response['total'] ?? ''}') ?? tracks.length,
        playCount: _formatCount(response['playnum']),
        coverUri: _httpsUri('${response['pic'] ?? ''}') ?? fallback.coverUri,
      ),
      tracks: tracks,
    );
  }

  static PageResult<OnlinePlaylist> _parseSearch(Object? raw, int page) {
    final response = _map(raw);
    final items = response['abslist'];
    if (items is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '歌单搜索响应异常');
    }
    final playlists = <OnlinePlaylist>[];
    for (final rawItem in items) {
      final item = _map(rawItem);
      final id = '${item['playlistid'] ?? ''}'.trim();
      final name =
          KuwoLeaderboardParser.decodeText('${item['name'] ?? ''}').trim();
      if (id.isEmpty || name.isEmpty) continue;
      playlists.add(OnlinePlaylist(
        id: id,
        source: OnlineSource.kuwo,
        name: name,
        author: KuwoLeaderboardParser.decodeText('${item['nickname'] ?? ''}')
            .trim(),
        description:
            KuwoLeaderboardParser.decodeText('${item['intro'] ?? ''}').trim(),
        trackCount: int.tryParse('${item['songnum'] ?? ''}') ?? 0,
        playCount: _formatCount(item['playcnt']),
        coverUri: _httpsUri('${item['pic'] ?? ''}'),
      ));
    }
    return PageResult(
        items: playlists,
        page: page,
        pageSize: 30,
        total: int.tryParse('${response['TOTAL'] ?? ''}') ?? playlists.length);
  }

  static Map<Object?, Object?> _map(Object? value) => value is Map
      ? Map<Object?, Object?>.from(value)
      : const <Object?, Object?>{};

  static Uri? _httpsUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }

  static String _formatCount(Object? value) {
    final count = int.tryParse('$value') ?? 0;
    if (count >= 100000000) return '${(count / 10000000).toStringAsFixed(1)}亿';
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return count == 0 ? '' : '$count';
  }
}
