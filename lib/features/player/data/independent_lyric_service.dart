import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/response_json.dart';
import '../../../domain/music.dart';
import 'lrclib_lyric_service.dart';

/// Independent of User API scripts and the currently enabled music source.
final class IndependentLyricService {
  IndependentLyricService(Dio dio)
      : _dio = dio,
        _fallback = LrcLibLyricService(dio);

  final Dio _dio;
  final LrcLibLyricService _fallback;

  Future<LyricPayload?> resolve(Track track) async {
    try {
      final lyric = await switch (track.sourceId) {
        'tx' => _qq(track),
        'kw' => _kuwo(track),
        'wy' => _netease(track),
        'mg' => _migu(track),
        'kg' => _kugou(track),
        _ => Future.value(null),
      };
      if (_hasContent(lyric)) return lyric;
    } on Object {
      // Public endpoints change independently; retain the shared fallback.
    }
    return _fallback.resolve(track);
  }

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
    final data = decodeJsonMap(response.data);
    if ('${data['code']}' != '0') return null;
    return LyricPayload(
        lyric: _decode(data['lyric']), tlyric: _decode(data['trans']));
  }

  Future<LyricPayload?> _kuwo(Track track) async {
    if (!RegExp(r'^\d+$').hasMatch(track.sourceTrackId)) return null;
    final response = await _dio.getUri<Object?>(
      Uri.https('m.kuwo.cn', '/newh5/singles/songinfoandlrc', {
        'musicId': track.sourceTrackId,
      }),
      options: Options(headers: const {'Referer': 'https://m.kuwo.cn/'}),
    );
    final data = decodeJsonMap(response.data)['data'];
    final lines = data is Map ? data['lrclist'] : null;
    if (lines is! List) return null;
    final lyric = lines
        .whereType<Map>()
        .map((line) {
          final time = '${line['time'] ?? ''}'.trim();
          final text = '${line['lineLyric'] ?? line['text'] ?? ''}'.trim();
          return time.isEmpty || text.isEmpty ? '' : '[$time]$text';
        })
        .where((line) => line.isNotEmpty)
        .join('\n');
    return lyric.isEmpty ? null : LyricPayload(lyric: lyric);
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
    final data = decodeJsonMap(response.data);
    return LyricPayload(
      lyric: _text(data['lrc']),
      tlyric: _text(data['tlyric']),
      rlyric: _text(data['romalrc']),
    );
  }

  Future<LyricPayload?> _migu(Track track) async {
    final uri = Uri.tryParse('${track.extra['lrcUrl'] ?? ''}'.trim());
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
    final candidates = decodeJsonMap(search.data)['candidates'];
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
    final lyric = _decode(decodeJsonMap(response.data)['content']);
    return lyric.isEmpty ? null : LyricPayload(lyric: lyric);
  }

  static bool _hasContent(LyricPayload? value) =>
      value != null &&
      [value.lyric, value.lxlyric, value.tlyric, value.rlyric]
          .any((part) => part.trim().isNotEmpty);

  static String _text(Object? value) => value is Map
      ? '${value['lyric'] ?? ''}'.trim()
      : value is String
          ? value.trim()
          : '';

  static String _decode(Object? value) {
    if (value == null) return '';
    final raw = '$value'.trim();
    if (raw.isEmpty) return '';
    try {
      return utf8.decode(base64.decode(raw)).trim();
    } on Object {
      return raw;
    }
  }
}
