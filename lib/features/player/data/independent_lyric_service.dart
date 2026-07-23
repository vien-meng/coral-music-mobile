import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/response_json.dart';
import '../../../domain/music.dart';
import 'kugou_krc.dart';
import 'lrclib_lyric_service.dart';
import 'netease_yrc.dart';

/// Independent of User API scripts and the currently enabled music source.
final class IndependentLyricService {
  IndependentLyricService(Dio dio)
      : _dio = dio,
        _fallback = LrcLibLyricService(dio);

  final Dio _dio;
  final LrcLibLyricService _fallback;

  Future<LyricPayload?> resolve(Track track) async {
    final independent = await _fallback.resolve(track);
    if (_hasContent(independent)) return independent;
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
      // Public platform endpoints are best-effort after independent lookup.
    }
    return null;
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
    final yrc = _text(data['yrc']);
    return LyricPayload(
      lyric: _text(data['lrc']),
      lxlyric: yrc.isEmpty ? '' : neteaseYrcToLx(yrc),
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
      Uri.https('lyrics.kugou.com', '/search', {
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
    final candidate = selectKugouLyricCandidate(candidates, track);
    if (candidate == null) return null;
    final isKrc = '${candidate['krctype']}' == '1' &&
        '${candidate['contenttype']}' != '1';
    final response = await _dio.getUri<Object?>(
      Uri.https('lyrics.kugou.com', '/download', {
        'ver': '1',
        'client': 'pc',
        'id': '${candidate['id'] ?? ''}',
        'accesskey': '${candidate['accesskey'] ?? ''}',
        'fmt': isKrc ? 'krc' : 'lrc',
        'charset': 'utf8',
      }),
      options: Options(headers: headers),
    );
    final lyric = _decode(decodeJsonMap(response.data)['content']);
    if (lyric.isEmpty) return null;
    if (!isKrc) return LyricPayload(lyric: lyric);
    final lxlyric = decodeKugouKrc(lyric);
    return lxlyric.isEmpty ? null : LyricPayload(lxlyric: lxlyric);
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

Map? selectKugouLyricCandidate(Object? raw, Track track) {
  if (raw is! List) return null;
  final candidates = raw.whereType<Map>().where((candidate) =>
      '${candidate['id'] ?? ''}'.isNotEmpty &&
      '${candidate['accesskey'] ?? ''}'.isNotEmpty);
  if (candidates.isEmpty) return null;
  final expectedDuration = track.duration?.inSeconds;
  return candidates.reduce((best, candidate) =>
      _kugouCandidateScore(candidate, track, expectedDuration) >
              _kugouCandidateScore(best, track, expectedDuration)
          ? candidate
          : best);
}

int _kugouCandidateScore(Map candidate, Track track, int? expectedDuration) {
  final title = '${candidate['song'] ?? candidate['songname'] ?? ''}'.trim();
  final artist =
      '${candidate['singer'] ?? candidate['singername'] ?? ''}'.trim();
  final duration =
      int.tryParse('${candidate['duration'] ?? candidate['timelength'] ?? ''}');
  return (_sameText(title, track.title) ? 4 : 0) +
      (_sameText(artist, track.artist) ? 3 : 0) +
      (expectedDuration != null &&
              duration != null &&
              ((duration > 1000 ? duration ~/ 1000 : duration) -
                          expectedDuration)
                      .abs() <=
                  3
          ? 2
          : 0) +
      ('${candidate['krctype']}' == '1' && '${candidate['contenttype']}' != '1'
          ? 1
          : 0);
}

bool _sameText(String left, String right) =>
    left.toLowerCase().replaceAll(RegExp(r'[\s\-_/·•]'), '') ==
    right.toLowerCase().replaceAll(RegExp(r'[\s\-_/·•]'), '');
