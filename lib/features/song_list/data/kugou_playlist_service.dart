import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../core/response_json.dart';
import '../../../domain/music.dart';
import 'kuwo_playlist_service.dart';

final class KugouPlaylistService implements PlaylistCatalogService {
  KugouPlaylistService(this._dio);

  final Dio _dio;
  @override
  Future<List<PlaylistTag>> getTags() async => const [];

  @override
  Future<PageResult<OnlinePlaylist>> getPopularPlaylists(
    int page, {
    String? tagId,
    String sortId = 'hot',
  }) async {
    if (page < 1) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '酷狗歌单页码无效');
    }
    try {
      final response = await _dio.getUri<Object?>(
        Uri.https('m.kugou.com', '/plist/index', {
          'json': 'true',
          'page': '$page',
        }),
      );
      return parseKugouPopularPlaylists(response.data, page: page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗歌单广场数据解析失败',
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
          code: AppFailureCode.invalidData, message: '酷狗歌单搜索参数无效');
    }
    try {
      final response = await _dio.getUri<Object?>(
        Uri.https('msearchretry.kugou.com', '/api/v3/search/special', {
          'keyword': keyword,
          'page': '$page',
          'pagesize': '30',
          'showtype': '10',
          'filter': '0',
          'version': '7910',
          'sver': '2',
        }),
      );
      return parseKugouSearchPlaylists(response.data, page: page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗歌单搜索数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PlaylistDetail> getPlaylistDetail(OnlinePlaylist playlist) async {
    if (playlist.source != OnlineSource.kugou || playlist.id.trim().isEmpty) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '酷狗歌单标识无效');
    }
    try {
      final response = await _dio.getUri<String>(
        Uri.https('m.kugou.com', '/plist/list/${playlist.id}', {
          'json': 'true',
        }),
        options: Options(responseType: ResponseType.plain),
      );
      return parseKugouPlaylistDetail(response.data ?? '', playlist);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗歌单详情数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }
}

PageResult<OnlinePlaylist> parseKugouPopularPlaylists(
  Object? raw, {
  required int page,
}) {
  final playlist = decodeJsonMap(raw)['plist'] as Map?;
  final data = playlist?['list'] as Map?;
  final items = data?['info'];
  if (items is! List) {
    throw const AppFailure(
        code: AppFailureCode.invalidData, message: '酷狗歌单广场响应异常');
  }
  final playlists = items
      .whereType<Map>()
      .map(_playlist)
      .whereType<OnlinePlaylist>()
      .toList(growable: false);
  return PageResult(
    items: playlists,
    page: page,
    pageSize: 30,
    total: int.tryParse('${data?['total'] ?? ''}') ?? playlists.length,
  );
}

PageResult<OnlinePlaylist> parseKugouSearchPlaylists(
  Object? raw, {
  required int page,
}) {
  final response = decodeJsonMap(raw);
  final data = response['data'] as Map?;
  final items = data?['info'];
  if ('${response['errcode'] ?? ''}' != '0' || items is! List) {
    throw const AppFailure(
        code: AppFailureCode.invalidData, message: '酷狗歌单搜索响应异常');
  }
  final playlists = items
      .whereType<Map>()
      .map(_playlist)
      .whereType<OnlinePlaylist>()
      .toList(growable: false);
  return PageResult(
    items: playlists,
    page: page,
    pageSize: 30,
    total: int.tryParse('${data?['total'] ?? ''}') ?? playlists.length,
  );
}

PlaylistDetail parseKugouPlaylistDetail(String body, OnlinePlaylist fallback) {
  final root = decodeJsonMap(body);
  final listNode = root['list'] as Map?;
  final trackList = listNode?['list'] as Map?;
  final rawTracks = trackList?['info'];
  if (rawTracks is! List) {
    throw const AppFailure(
        code: AppFailureCode.invalidData, message: '酷狗歌单歌曲缺失');
  }
  final tracks = rawTracks
      .whereType<Map>()
      .map(_track)
      .whereType<Track>()
      .toList(growable: false);
  if (tracks.isEmpty) {
    throw const AppFailure(
        code: AppFailureCode.invalidData, message: '酷狗歌单歌曲缺失');
  }
  final info = (root['info'] as Map?)?['list'] as Map?;
  return PlaylistDetail(
    playlist: OnlinePlaylist(
      id: fallback.id,
      source: OnlineSource.kugou,
      name: '${info?['specialname'] ?? fallback.name}'.trim(),
      author: '${info?['nickname'] ?? fallback.author}'.trim(),
      description: '${info?['intro'] ?? fallback.description}'.trim(),
      trackCount: tracks.length,
      coverUri:
          _uri(info?['imgurl']) ?? fallback.coverUri ?? tracks.first.coverUri,
    ),
    tracks: tracks,
  );
}

OnlinePlaylist? _playlist(Map item) {
  final id = '${item['specialid'] ?? ''}'.trim();
  final name = '${item['specialname'] ?? ''}'.trim();
  if (id.isEmpty || name.isEmpty) return null;
  return OnlinePlaylist(
    id: id,
    source: OnlineSource.kugou,
    name: name,
    author: '${item['nickname'] ?? ''}'.trim(),
    description: '${item['intro'] ?? ''}'.trim(),
    trackCount: int.tryParse('${item['songcount'] ?? ''}') ?? 0,
    playCount: _formatCount(item['playcount']),
    coverUri: _uri(item['imgurl']),
  );
}

Track? _track(Map item) {
  final hash = '${item['hash'] ?? item['HASH'] ?? ''}'.trim();
  final filename =
      '${item['filename'] ?? item['songname'] ?? item['audio_name'] ?? ''}'
          .trim();
  if (hash.isEmpty || filename.isEmpty) return null;
  var title = filename;
  var artist = '${item['author_name'] ?? item['singername'] ?? ''}'.trim();
  if (artist.isEmpty) {
    final dashIndex = filename.indexOf(' - ');
    if (dashIndex > 0) {
      artist = filename.substring(0, dashIndex).trim();
      title = filename.substring(dashIndex + 3).trim();
    }
  }
  final meta = <String, Map<String, Object?>>{};
  void add(String name, String hashKey, String sizeKey) {
    final qualityHash = '${item[hashKey] ?? ''}'.trim();
    final size = int.tryParse('${item[sizeKey] ?? ''}') ?? 0;
    if (qualityHash.isNotEmpty && size > 0) {
      meta[name] = {'hash': qualityHash, 'size': size};
    }
  }

  add('128k', 'hash', 'filesize');
  add('320k', '320hash', '320filesize');
  add('flac', 'sqhash', 'sqfilesize');
  final trans = item['trans_param'];
  return Track(
    sourceKind: TrackSourceKind.online,
    sourceId: OnlineSource.kugou.id,
    sourceTrackId: '${item['audio_id'] ?? hash}',
    title: title,
    artist: artist,
    album: '${item['album_name'] ?? ''}'.trim(),
    duration: _duration(item['duration'] ?? item['timelength']),
    coverUri: _uri(trans is Map ? trans['union_cover'] : null),
    availableQualities: [
      if (meta.containsKey('flac')) AudioQuality.flac,
      if (meta.containsKey('320k')) AudioQuality.high320k,
      if (meta.containsKey('128k')) AudioQuality.standard128k,
    ],
    extra: {
      'songId': item['audio_id'],
      'albumId': item['album_id'],
      'hash': hash,
      'qualityMeta': meta,
    },
  );
}

Duration? _duration(Object? value) {
  final milliseconds = int.tryParse('$value');
  if (milliseconds == null || milliseconds <= 0) return null;
  return Duration(
      milliseconds: milliseconds < 1000 ? milliseconds * 1000 : milliseconds);
}

Uri? _uri(Object? value) {
  final raw = '$value'.trim().replaceAll('{size}', '480');
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return null;
  return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
}

String _formatCount(Object? value) {
  final count = int.tryParse('$value') ?? 0;
  if (count >= 100000000) return '${(count / 10000000).toStringAsFixed(1)}亿';
  if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
  return count == 0 ? '' : '$count';
}
