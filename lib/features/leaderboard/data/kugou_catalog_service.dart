import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../core/response_json.dart';
import '../../../domain/music.dart';
import 'kugou_search_parser.dart';
import 'online_catalog_service.dart';

final class KugouCatalogService implements OnlineCatalogService {
  KugouCatalogService(this._dio);

  final Dio _dio;
  static const _boards = <LeaderboardBoard>[
    LeaderboardBoard(
        id: 'kg__8888',
        source: OnlineSource.kugou,
        name: 'TOP500',
        remoteId: '8888'),
    LeaderboardBoard(
        id: 'kg__6666',
        source: OnlineSource.kugou,
        name: '飙升榜',
        remoteId: '6666'),
    LeaderboardBoard(
        id: 'kg__23784',
        source: OnlineSource.kugou,
        name: '网络热歌榜',
        remoteId: '23784'),
    LeaderboardBoard(
        id: 'kg__33160',
        source: OnlineSource.kugou,
        name: '电音热歌榜',
        remoteId: '33160'),
  ];

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(
          OnlineSource source) async =>
      source == OnlineSource.kugou ? _boards : throw _unsupported('排行榜');

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  ) async {
    final board = _boards.where((item) => item.id == boardId).firstOrNull;
    if (source != OnlineSource.kugou || page != 1 || board == null) {
      throw const AppFailure(
          code: AppFailureCode.invalidData, message: '酷狗榜单请求参数无效');
    }
    try {
      final response = await _dio.getUri<String>(
        Uri.https('www.kugou.com', '/yy/rank/home/1-${board.remoteId}.html'),
        options: Options(
          responseType: ResponseType.plain,
          headers: const {
            'Referer': 'https://www.kugou.com/yy/html/rank.html',
          },
        ),
      );
      final result = parseKugouRankHtml(response.data ?? '');
      return _withArtwork(result);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗榜单数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  ) async {
    final keyword = query.trim();
    if (source != OnlineSource.kugou || keyword.isEmpty || page < 1) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗音乐搜索请求参数无效',
      );
    }
    final uri = Uri.https('songsearch.kugou.com', '/song_search_v2', {
      'keyword': keyword,
      'page': '$page',
      'pagesize': '30',
      'userid': '0',
      'clientver': '',
      'platform': 'WebFilter',
      'filter': '2',
      'iscorrection': '1',
      'privilege_filter': '0',
      'area_code': '1',
    });
    try {
      final response = await _dio.getUri<Object?>(
        uri,
        options: Options(headers: const {
          'Referer': 'https://kugou.com',
          'Origin': 'https://kugou.com',
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) '
              'AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 '
              'Mobile/13B143 Safari/601.1',
        }),
      );
      return KugouSearchParser.parse(response.data, page: page);
    } on DioException catch (error) {
      throw mapDioException(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗音乐搜索数据解析失败',
        diagnostic: error.runtimeType.toString(),
      );
    }
  }

  AppFailure _unsupported(String capability) => AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗音乐暂未接入$capability',
      );

  Future<PageResult<Track>> _withArtwork(PageResult<Track> result) async {
    if (result.items.isEmpty) return result;
    try {
      final response = await _dio.postUri<Object?>(
        Uri.http('media.store.kugou.com', '/v1/get_res_privilege'),
        data: {
          'appid': 1001,
          'area_code': '1',
          'behavior': 'play',
          'clientver': '9020',
          'need_hash_offset': 1,
          'relate': 1,
          'resource': [
            for (final track in result.items)
              {
                // The public endpoint currently requires this historical typo.
                'albunm_audio_id': track.extra['hash'],
                'album_id': track.extra['albumId'],
                'hash': track.extra['hash'],
                'id': 0,
                'name': '${track.artist} - ${track.title}.mp3',
                'type': 'audio',
              },
          ],
          'token': '',
          'userid': 2626431536,
          'vip': 1,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          headers: const {
            'KG-RC': '1',
            'KG-THash': 'expand_search_manager.cpp:852736169:451',
            'User-Agent': 'KuGou2012-9020-ExpandSearchManager',
          },
        ),
      );
      final dynamic rawData = response.data;
      final Map values;
      if (rawData is Map) {
        values = rawData;
      } else if (rawData is String) {
        values = decodeJsonMap(rawData);
      } else {
        debugPrint('[KugouArtwork] response.data is ${rawData.runtimeType}, cannot parse');
        return result;
      }
      final resources = values['data'];
      if (resources is! List) {
        debugPrint('[KugouArtwork] response has no data list, keys=${values.keys.toList()}');
        return result;
      }
      final covers = <String, Uri>{};
      for (final resource in resources.whereType<Map>()) {
        final hash = '${resource['hash'] ?? ''}'.trim();
        final info = resource['info'];
        final cover = info is Map ? _kugouCoverUri(info['image']) : null;
        if (hash.isNotEmpty && cover != null) covers[hash] = cover;
      }
      debugPrint('[KugouArtwork] tracks=${result.items.length} covers=${covers.length}');
      if (covers.isEmpty) return result;
      return PageResult(
        items: [
          for (final track in result.items)
            _copyTrack(track, covers[track.extra['hash']]),
        ],
        page: result.page,
        pageSize: result.pageSize,
        total: result.total,
      );
    } on Object catch (error, stack) {
      debugPrint('[KugouArtwork] failed: $error\n$stack');
      return result;
    }
  }
}

Track _copyTrack(Track track, Uri? coverUri) => coverUri == null
    ? track
    : Track(
        sourceKind: track.sourceKind,
        sourceId: track.sourceId,
        sourceTrackId: track.sourceTrackId,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        coverUri: coverUri,
        localUri: track.localUri,
        availableQualities: track.availableQualities,
        extra: track.extra,
      );

Uri? _kugouCoverUri(Object? value) {
  final uri = Uri.tryParse('${value ?? ''}'.replaceAll('{size}', '240'));
  if (uri == null || uri.host.isEmpty) return null;
  return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
}

PageResult<Track> parseKugouRankHtml(String html) {
  final raw = RegExp(r'global\.features\s*=\s*(\[.+?\]);', dotAll: true)
      .firstMatch(html)
      ?.group(1);
  if (raw == null) {
    throw const AppFailure(
        code: AppFailureCode.invalidData, message: '酷狗榜单歌曲缺失');
  }
  final values = jsonDecode(raw);
  if (values is! List) {
    throw const AppFailure(
        code: AppFailureCode.invalidData, message: '酷狗榜单歌曲缺失');
  }
  final tracks = <Track>[];
  final ids = <String>{};
  for (final value in values.whereType<Map>()) {
    final hash = '${value['Hash'] ?? ''}'.trim();
    final artist = '${value['author_name'] ?? ''}'.trim();
    final filename = '${value['FileName'] ?? ''}'.trim();
    final title = artist.isEmpty
        ? filename
        : filename.replaceFirst(
            RegExp('^${RegExp.escape(artist)}\\s*-\\s*'), '');
    if (hash.isEmpty || title.isEmpty || !ids.add(hash)) continue;
    final size = int.tryParse('${value['size'] ?? ''}') ?? 0;
    tracks.add(Track(
      sourceKind: TrackSourceKind.online,
      sourceId: OnlineSource.kugou.id,
      sourceTrackId: hash,
      title: title.replaceAll('&amp;', '&'),
      artist: artist.replaceAll('&amp;', '&'),
      duration: _kugouDuration(value['timeLen']),
      availableQualities:
          size > 0 ? const [AudioQuality.standard128k] : const [],
      extra: {
        'hash': hash,
        'albumId': value['album_id'],
        if (size > 0)
          'qualityMeta': {
            '128k': {'hash': hash, 'size': size},
          },
      },
    ));
  }
  return PageResult(
      items: tracks, page: 1, pageSize: tracks.length, total: tracks.length);
}

Duration? _kugouDuration(Object? value) {
  final seconds = num.tryParse('$value');
  return seconds == null || seconds <= 0
      ? null
      : Duration(milliseconds: (seconds * 1000).round());
}
