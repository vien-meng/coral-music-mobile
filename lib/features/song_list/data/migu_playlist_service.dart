import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import 'kuwo_playlist_service.dart';

final class MiguPlaylistService implements PlaylistCatalogService {
  MiguPlaylistService(this._dio);

  final Dio _dio;
  static const _pageSize = 30;
  static const _detailPageSize = 50;
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) '
        'AppleWebKit/605.1.15 Version/13.0.3 Mobile/15E148 Safari/604.1',
    'Referer': 'https://m.music.migu.cn/',
  };

  @override
  Future<List<PlaylistTag>> getTags() async {
    const uri =
        'https://app.c.nf.migu.cn/pc/v1.0/template/musiclistplaza-taglist/release';
    try {
      final response = await _dio.get<Object?>(uri, options: _options());
      return parseTags(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '咪咕音乐歌单标签数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PageResult<OnlinePlaylist>> getPopularPlaylists(
    int page, {
    String? tagId,
    String sortId = 'hot',
  }) async {
    if (page < 1) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '咪咕音乐歌单页码无效',
      );
    }
    final uri = tagId == null || tagId.isEmpty
        ? Uri.https('app.c.nf.migu.cn',
            '/pc/bmw/page-data/playlist-square-recommend/v1.0', {
            'templateVersion': '2',
            'pageNo': '$page',
          })
        : Uri.https('app.c.nf.migu.cn',
            '/pc/v1.0/template/musiclistplaza-listbytag/release', {
            'pageNumber': '$page',
            'templateVersion': '2',
            'tagId': tagId,
          });
    try {
      final response = await _dio.getUri<Object?>(uri, options: _options());
      return parsePopular(response.data, page: page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '咪咕音乐歌单广场数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PageResult<OnlinePlaylist>> searchPlaylists(
    String query,
    int page,
  ) async =>
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '咪咕音乐歌单搜索暂未接入',
      );

  @override
  Future<PlaylistDetail> getPlaylistDetail(OnlinePlaylist playlist) async {
    if (playlist.source != OnlineSource.migu || playlist.id.trim().isEmpty) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '咪咕音乐歌单标识无效',
      );
    }
    final id = playlist.id;
    final songs = Uri.https(
      'app.c.nf.migu.cn',
      '/MIGUM3.0/resource/playlist/song/v2.0',
      {'pageNo': '1', 'pageSize': '$_detailPageSize', 'playlistId': id},
    );
    final info = Uri.https(
      'c.musicapp.migu.cn',
      '/MIGUM3.0/resource/playlist/v2.0',
      {'playlistId': id},
    );
    try {
      final responses = await Future.wait([
        _dio.getUri<Object?>(songs, options: _options()),
        _dio.getUri<Object?>(info, options: _options()),
      ]);
      return parseDetail(
        songs: responses[0].data,
        info: responses[1].data,
        fallback: playlist,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '咪咕音乐歌单详情数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  static List<PlaylistTag> parseTags(Object? raw) {
    final response = raw is Map ? raw : null;
    final data = response?['data'];
    if (response?['code'] != '000000' || data is! List) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '咪咕音乐歌单标签数据格式异常',
      );
    }
    final tags = <PlaylistTag>[];
    final ids = <String>{};
    for (final group in data.whereType<Map>()) {
      final content = group['content'];
      if (content is! List) continue;
      for (final item in content.whereType<Map>()) {
        final texts = item['texts'];
        final name = texts is List && texts.isNotEmpty ? '${texts.first}' : '';
        final id = texts is List && texts.length > 1 ? '${texts[1]}' : '';
        if (name.trim().isNotEmpty && id.trim().isNotEmpty && ids.add(id)) {
          tags.add(PlaylistTag(id: id, name: name.trim()));
        }
      }
    }
    return tags;
  }

  static PageResult<OnlinePlaylist> parsePopular(
    Object? raw, {
    required int page,
  }) {
    final response = raw is Map ? raw : null;
    final data = response?['data'];
    if (response?['code'] != '000000' || data is! Map) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '咪咕音乐歌单广场数据格式异常',
      );
    }
    final values = <Map>[];
    void collect(Object? value) {
      if (value is List) {
        for (final item in value) collect(item);
        return;
      }
      if (value is! Map) return;
      if (value['resType'] == '2021' && value['resId'] != null) {
        values.add(value);
      }
      collect(value['contents']);
    }

    collect(data['contents']);
    if (values.isEmpty) {
      final contentItemList = data['contentItemList'];
      if (contentItemList is List) {
        for (final section in contentItemList.whereType<Map>()) {
          final items = section['itemList'];
          if (items is! List) continue;
          for (final item in items.whereType<Map>()) {
            final event = item['logEvent'];
            final id = event is Map ? event['contentId'] : null;
            if (id == null) continue;
            values.add({
              'resType': '2021',
              'resId': id,
              'txt': item['title'],
              'txt2': '',
              'img': item['imageUrl'],
            });
          }
        }
      }
    }
    final playlists = <OnlinePlaylist>[];
    final ids = <String>{};
    for (final item in values) {
      final id = '${item['resId'] ?? ''}'.trim();
      final name = '${item['txt'] ?? ''}'.trim();
      if (id.isEmpty || name.isEmpty || !ids.add(id)) continue;
      playlists.add(OnlinePlaylist(
        id: id,
        source: OnlineSource.migu,
        name: name,
        description: '${item['txt2'] ?? ''}'.trim(),
        coverUri: _httpsUri(item['img']),
      ));
    }
    final total = int.tryParse('${data['totalCount'] ?? ''}') ??
        (playlists.length < _pageSize
            ? (page - 1) * _pageSize + playlists.length
            : page * _pageSize + 1);
    return PageResult(
      items: playlists,
      page: page,
      pageSize: _pageSize,
      total: total,
    );
  }

  static PlaylistDetail parseDetail({
    required Object? songs,
    required Object? info,
    required OnlinePlaylist fallback,
  }) {
    final songResponse = songs is Map ? songs : null;
    final songData = songResponse?['data'];
    final rawSongs = songData is Map ? songData['songList'] : null;
    final infoResponse = info is Map ? info : null;
    final infoData = infoResponse?['data'];
    if (songResponse?['code'] != '000000' ||
        rawSongs is! List ||
        infoResponse?['code'] != '000000' ||
        infoData is! Map) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '咪咕音乐歌单详情格式异常',
      );
    }
    final tracks = <Track>[];
    final ids = <String>{};
    for (final item in rawSongs.whereType<Map>()) {
      final id = '${item['songId'] ?? ''}'.trim();
      final title = '${item['songName'] ?? ''}'.trim();
      if (id.isEmpty || title.isEmpty || !ids.add(id)) continue;
      tracks.add(Track(
        sourceKind: TrackSourceKind.online,
        sourceId: OnlineSource.migu.id,
        sourceTrackId: id,
        title: title,
        artist: _artists(item['singerList']),
        album: '${item['album'] ?? ''}'.trim(),
        duration: _duration(item['duration']),
        coverUri: _httpsUri(item['img3'] ?? item['img2'] ?? item['img1']),
        availableQualities: _qualities(item['audioFormats']),
        extra: {
          'albumId': item['albumId'],
          'copyrightId': item['copyrightId'],
        },
      ));
    }
    final image = infoData['imgItem'];
    final opNum = infoData['opNumItem'];
    return PlaylistDetail(
      playlist: OnlinePlaylist(
        id: fallback.id,
        source: OnlineSource.migu,
        name: '${infoData['title'] ?? fallback.name}'.trim(),
        author: '${infoData['ownerName'] ?? fallback.author}'.trim(),
        description: '${infoData['summary'] ?? fallback.description}'.trim(),
        trackCount:
            int.tryParse('${songData['totalCount'] ?? ''}') ?? tracks.length,
        playCount: _formatCount(opNum is Map ? opNum['playNum'] : null),
        coverUri:
            _httpsUri(image is Map ? image['img'] : null) ?? fallback.coverUri,
      ),
      tracks: tracks,
    );
  }

  Options _options() => Options(headers: _headers);

  static String _artists(Object? raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((item) => '${item['name'] ?? ''}'.trim())
          .where((item) => item.isNotEmpty)
          .join('、')
      : '';

  static Duration? _duration(Object? value) {
    final seconds = int.tryParse('$value');
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }

  static List<AudioQuality> _qualities(Object? raw) {
    final values = <AudioQuality>{};
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        switch (item['formatType']) {
          case 'PQ':
            values.add(AudioQuality.standard128k);
          case 'HQ':
            values.add(AudioQuality.high320k);
          case 'SQ':
            values.add(AudioQuality.flac);
          case 'ZQ':
            values.add(AudioQuality.flac24bit);
        }
      }
    }
    return AudioQuality.values.where(values.contains).toList(growable: false);
  }

  static Uri? _httpsUri(Object? value) {
    final uri = Uri.tryParse('$value'.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }

  static String _formatCount(Object? value) {
    final count = int.tryParse('$value') ?? 0;
    if (count >= 100000000) return '${(count / 10000000).toStringAsFixed(1)}亿';
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return count == 0 ? '' : '$count';
  }
}
