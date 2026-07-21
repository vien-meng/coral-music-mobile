import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import 'online_catalog_service.dart';
import 'migu_track_support.dart';

final class MiguCatalogService implements OnlineCatalogService {
  MiguCatalogService(this._dio);

  final Dio _dio;

  static const _boards = <LeaderboardBoard>[
    LeaderboardBoard(
        id: 'mg__27553319',
        source: OnlineSource.migu,
        name: '新歌榜',
        remoteId: '27553319'),
    LeaderboardBoard(
        id: 'mg__27186466',
        source: OnlineSource.migu,
        name: '热歌榜',
        remoteId: '27186466'),
    LeaderboardBoard(
        id: 'mg__27553408',
        source: OnlineSource.migu,
        name: '原创榜',
        remoteId: '27553408'),
    LeaderboardBoard(
        id: 'mg__75959118',
        source: OnlineSource.migu,
        name: '音乐风向榜',
        remoteId: '75959118'),
    LeaderboardBoard(
        id: 'mg__23189800',
        source: OnlineSource.migu,
        name: '港台榜',
        remoteId: '23189800'),
    LeaderboardBoard(
        id: 'mg__23189399',
        source: OnlineSource.migu,
        name: '内地榜',
        remoteId: '23189399'),
    LeaderboardBoard(
        id: 'mg__19190036',
        source: OnlineSource.migu,
        name: '欧美榜',
        remoteId: '19190036'),
  ];

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(
      OnlineSource source) async {
    if (source != OnlineSource.migu) throw _unsupported('排行榜');
    return _boards;
  }

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  ) async {
    final board = _boards.where((item) => item.id == boardId).firstOrNull;
    if (source != OnlineSource.migu || page != 1 || board == null) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '咪咕榜单请求参数无效');
    }
    final uri = Uri.https(
        'app.c.nf.migu.cn', '/MIGUM2.0/v1.0/content/querycontentbyId.do', {
      'columnId': board.remoteId,
      'needAll': '0',
    });
    try {
      final response = await _dio.getUri<Object?>(uri);
      return _parse(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
          code: AppFailureCode.invalidData,
          message: '咪咕榜单数据解析失败',
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
    if (source != OnlineSource.migu || keyword.isEmpty || page < 1) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '咪咕搜索请求参数无效');
    }
    const deviceId = '963B7AA0D21511ED807EE5846EC87D20';
    const salt =
        '6cdc72a439cef99a3418d2a78aa28c73yyapp2d16148780a1dcc7408e06336b98cfd50';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature =
        md5.convert(utf8.encode('$keyword$salt$deviceId$timestamp')).toString();
    final uri =
        Uri.https('jadeite.migu.cn', '/music_search/v3/search/searchAll', {
      'isCorrect': '0',
      'isCopyright': '1',
      'searchSwitch':
          '{"song":1,"album":0,"singer":0,"tagSong":1,"mvSong":0,"bestShow":1,"songlist":0,"lyricSong":0}',
      'pageSize': '20',
      'text': keyword,
      'pageNo': '$page',
      'sort': '0',
      'sid': 'USS',
    });
    try {
      final response = await _dio.getUri<Object?>(uri,
          options: Options(headers: {
            'uiVersion': 'A_music_3.6.1',
            'deviceId': deviceId,
            'timestamp': timestamp,
            'sign': signature,
            'channel': '0146921'
          }));
      return parseSearch(response.data, page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
          code: AppFailureCode.invalidData,
          message: '咪咕搜索数据解析失败',
          diagnostic: error.runtimeType.toString());
    }
  }

  static PageResult<Track> _parse(Object? raw) {
    if (raw is! Map || raw['code'] != '000000') {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '咪咕榜单响应异常');
    }
    final column = raw['columnInfo'];
    final contents = column is Map ? column['contents'] : null;
    if (contents is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '咪咕榜单歌曲缺失');
    }
    final tracks = <Track>[];
    final ids = <String>{};
    for (final content in contents) {
      final object = content is Map ? content['objectInfo'] : null;
      if (object is! Map) continue;
      final id = '${object['songId'] ?? ''}'.trim();
      final title = '${object['songName'] ?? ''}'.trim();
      if (id.isEmpty || title.isEmpty || !ids.add(id)) continue;
      tracks.add(Track(
        sourceKind: TrackSourceKind.online,
        sourceId: OnlineSource.migu.id,
        sourceTrackId: id,
        title: title,
        artist: _artists(object['artists']),
        album: '${object['album'] ?? ''}'.trim(),
        duration: _duration('${object['length'] ?? ''}'),
        coverUri: _cover(object['albumImgs']),
        availableQualities: miguAudioQualities(object['newRateFormats']),
        extra: {
          'songId': object['songId'],
          'albumId': object['albumId'],
          'copyrightId': object['copyrightId'],
          'qualityMeta': miguQualityMeta(object['newRateFormats']),
          'lrcUrl': object['lyricUrl'] ?? object['lrcUrl'],
          'mrcUrl': object['mrcUrl'] ?? object['mrcurl'],
          'trcUrl': object['trcUrl'],
        },
      ));
    }
    return PageResult(
        items: tracks, page: 1, pageSize: tracks.length, total: tracks.length);
  }

  static PageResult<Track> parseSearch(Object? raw, int page) {
    final result = raw is Map ? raw['songResultData'] : null;
    final groups = result is Map ? result['resultList'] : null;
    if (groups is! List) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '咪咕搜索歌曲缺失');
    }
    final tracks = <Track>[];
    final ids = <String>{};
    for (final group in groups.whereType<List>()) {
      for (final song in group.whereType<Map>()) {
        final id = '${song['songId'] ?? ''}';
        final title = '${song['name'] ?? ''}'.trim();
        if (id.isEmpty || title.isEmpty || !ids.add(id)) continue;
        final singers = song['singerList'];
        final duration = int.tryParse('${song['duration'] ?? ''}');
        tracks.add(Track(
            sourceKind: TrackSourceKind.online,
            sourceId: OnlineSource.migu.id,
            sourceTrackId: id,
            title: title,
            artist: singers is List
                ? singers
                    .whereType<Map>()
                    .map((item) => '${item['name'] ?? ''}')
                    .where((name) => name.isNotEmpty)
                    .join('、')
                : '',
            album: '${song['album'] ?? ''}',
            duration: duration == null ? null : Duration(seconds: duration),
            coverUri: _searchCover(song),
            availableQualities: miguAudioQualities(song['audioFormats']),
            extra: {
              'songId': song['songId'],
              'albumId': song['albumId'],
              'copyrightId': song['copyrightId'],
              'qualityMeta': miguQualityMeta(song['audioFormats']),
              'lrcUrl': song['lyricUrl'] ?? song['lrcUrl'],
              'mrcUrl': song['mrcUrl'] ?? song['mrcurl'],
              'trcUrl': song['trcUrl'],
            }));
      }
    }
    return PageResult(
        items: tracks,
        page: page,
        pageSize: 20,
        total: int.tryParse('${result['totalCount'] ?? ''}') ?? tracks.length);
  }

  static String _artists(Object? raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((artist) => '${artist['name'] ?? ''}'.trim())
          .where((name) => name.isNotEmpty)
          .join('、')
      : '';

  static Duration? _duration(String value) {
    final match = RegExp(r'(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    return Duration(
        minutes: int.parse(match.group(1)!),
        seconds: int.parse(match.group(2)!));
  }

  static Uri? _cover(Object? raw) {
    if (raw is! List || raw.isEmpty || raw.first is! Map) return null;
    final uri = Uri.tryParse('${(raw.first as Map)['img'] ?? ''}');
    return uri?.scheme == 'http' ? uri!.replace(scheme: 'https') : uri;
  }

  static Uri? _searchCover(Map song) {
    final direct = song['img3'] ?? song['img2'] ?? song['img1'];
    final images = song['imgItems'];
    final nested = images is List && images.isNotEmpty && images.first is Map
        ? (images.first as Map)['img']
        : null;
    final raw = '${direct ?? nested ?? ''}'.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.host.isEmpty) {
      return Uri.https(
        'd.musicapp.migu.cn',
        raw.startsWith('/') ? raw : '/$raw',
      );
    }
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }

  AppFailure _unsupported(String feature) =>
      AppFailure(code: AppFailureCode.invalidData, message: '咪咕音乐暂未接入$feature');
}
