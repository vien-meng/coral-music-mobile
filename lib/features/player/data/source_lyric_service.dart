import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../domain/music.dart';

final class SourceLyricService {
  const SourceLyricService(this._dio);

  final Dio _dio;

  Future<LyricPayload?> resolve(Track track) => switch (track.sourceId) {
        'tx' => _qq(track),
        'wy' => _netease(track),
        'mg' => _migu(track),
        'kg' => _kugou(track),
        _ => Future.value(null),
      };

  Future<LyricPayload?> _qq(Track track) async {
    final response = await _dio.getUri<Object?>(
      Uri.https('c.y.qq.com', '/lyric/fcgi-bin/fcg_query_lyric_new.fcg', {
        'songmid': track.sourceTrackId,
        'g_tk': '5381',
        'loginUin': '0',
        'hostUin': '0',
        'format': 'json',
        'nobase64': '1',
        'platform': 'yqq',
      }),
      options: Options(headers: const {'Referer': 'https://y.qq.com/'}),
    );
    final data = response.data is Map ? response.data as Map : null;
    if (data == null || data['code'] != 0) return null;
    return LyricPayload(
      lyric: _decode(data['lyric']),
      tlyric: _decode(data['trans']),
    );
  }

  Future<LyricPayload?> _netease(Track track) async {
    final response = await _dio.getUri<Object?>(
      Uri.https('music.163.com', '/api/song/lyric', {
        'id': track.sourceTrackId,
        'lv': '-1',
        'kv': '-1',
        'tv': '-1',
      }),
      options: Options(headers: const {'Referer': 'https://music.163.com/'}),
    );
    final data = response.data is Map ? response.data as Map : null;
    return LyricPayload(
      lyric: _text(data?['lrc']),
      tlyric: _text(data?['tlyric']),
      rlyric: _text(data?['romalrc']),
    );
  }

  Future<LyricPayload?> _migu(Track track) async {
    final raw =
        '${track.extra['mrcUrl'] ?? track.extra['lrcUrl'] ?? ''}'.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return null;
    final response = await _dio.getUri<String>(
      uri,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {'Referer': 'https://app.c.nf.migu.cn/'},
      ),
    );
    final lyric = response.data?.trim() ?? '';
    return lyric.isEmpty ? null : LyricPayload(lyric: lyric);
  }

  Future<LyricPayload?> _kugou(Track track) async {
    final hash = '${track.extra['hash'] ?? ''}'.trim();
    if (hash.isEmpty || track.duration == null) return null;
    const headers = {
      'KG-RC': '1',
      'KG-THash': 'expand_search_manager.cpp:852736169:451',
      'User-Agent': 'KuGou2012-9020-ExpandSearchManager',
    };
    final search = await _dio.getUri<Object?>(
      Uri.http('lyrics.kugou.com', '/search', {
        'ver': '1',
        'man': 'yes',
        'client': 'pc',
        'keyword': track.title,
        'hash': hash,
        'timelength': '${track.duration!.inSeconds}',
      }),
      options: Options(headers: headers),
    );
    final candidates =
        search.data is Map ? (search.data as Map)['candidates'] : null;
    final candidate =
        candidates is List ? candidates.whereType<Map>().firstOrNull : null;
    if (candidate == null) return null;
    final response = await _dio.getUri<Object?>(
      Uri.http('lyrics.kugou.com', '/download', {
        'ver': '1',
        'client': 'pc',
        'id': '${candidate['id'] ?? ''}',
        'accesskey': '${candidate['accesskey'] ?? ''}',
        'fmt': 'lrc',
        'charset': 'utf8',
      }),
      options: Options(headers: headers),
    );
    final data = response.data is Map ? response.data as Map : null;
    final lyric = _decode(data?['content']);
    return lyric.isEmpty ? null : LyricPayload(lyric: lyric);
  }

  static String _text(Object? value) => value is Map
      ? '${value['lyric'] ?? ''}'.trim()
      : value is String
          ? value.trim()
          : '';

  static String _decode(Object? value) {
    final raw = '$value'.trim();
    if (raw.isEmpty) return '';
    try {
      return utf8.decode(base64.decode(raw)).trim();
    } on Object {
      return raw;
    }
  }
}
