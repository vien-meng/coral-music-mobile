import 'package:dio/dio.dart';

import '../../../domain/music.dart';

final class LrcLibLyricService {
  const LrcLibLyricService(this._dio);

  final Dio _dio;

  Future<LyricPayload?> resolve(Track track) async {
    if (track.duration != null) {
      try {
        final response = await _dio.get<Object?>(
          'https://lrclib.net/api/get',
          queryParameters: {
            'track_name': track.title,
            'artist_name': track.artist,
            if (track.album?.trim().isNotEmpty == true)
              'album_name': track.album,
            'duration': track.duration!.inSeconds,
          },
        );
        final exact = parseLrcLibPayload(response.data);
        if (exact != null) return exact;
      } on DioException {
        // Exact lookup is optional; continue with keyword search when the
        // public service rejects, throttles, or cannot match this source.
      } on Object {
        // Keep the keyword fallback available for malformed exact responses.
      }
    }

    final byTitleAndArtist = await _search(track, includeArtist: true);
    if (byTitleAndArtist != null || track.artist.trim().isEmpty) {
      return byTitleAndArtist;
    }
    return _search(track, includeArtist: false);
  }

  Future<LyricPayload?> _search(
    Track track, {
    required bool includeArtist,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        'https://lrclib.net/api/search',
        queryParameters: {
          'track_name': track.title,
          if (includeArtist) 'artist_name': track.artist,
          'limit': 20,
        },
      );
      return selectLrcLibSearchResult(response.data, track);
    } on DioException {
      // A public lyrics backend is best-effort; leave the page retryable.
      return null;
    } on Object {
      return null;
    }
  }
}

LyricPayload? selectLrcLibSearchResult(Object? raw, Track track) {
  if (raw is! List) return null;
  final title = _normalize(track.title);
  final artist = _normalize(track.artist);
  LyricPayload? best;
  var bestScore = 0.0;
  for (final item in raw) {
    if (item is! Map) continue;
    final payload = parseLrcLibPayload(item);
    if (payload == null) continue;
    final candidateTitle = _normalize(item['trackName'] ?? item['name']);
    final candidateArtist = _normalize(item['artistName']);
    final titleScore = _similarity(title, candidateTitle);
    // ponytail: reject weak title matches; expose manual lyric selection if
    // broader fuzzy matching is needed.
    if (titleScore < .45) continue;
    var score = titleScore * 3 + _similarity(artist, candidateArtist) * 3;
    if (item['syncedLyrics'] is String &&
        (item['syncedLyrics'] as String).trim().isNotEmpty) {
      score += .2;
    }
    if (score > bestScore) {
      bestScore = score;
      best = payload;
    }
  }
  return best;
}

String _normalize(Object? value) =>
    '$value'.toLowerCase().replaceAll(RegExp(r'[\s\-_/·•]'), '').trim();

double _similarity(String left, String right) {
  if (left == right) return 1;
  if (left.isEmpty || right.isEmpty) return 0;
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var row = 0; row < left.length; row++) {
    final current = List<int>.filled(right.length + 1, 0)..[0] = row + 1;
    for (var column = 0; column < right.length; column++) {
      current[column + 1] = [
        previous[column + 1] + 1,
        current[column] + 1,
        previous[column] + (left[row] == right[column] ? 0 : 1),
      ].reduce((best, value) => value < best ? value : best);
    }
    previous = current;
  }
  return 1 -
      previous.last / (left.length > right.length ? left.length : right.length);
}

LyricPayload? parseLrcLibPayload(Object? raw) {
  if (raw is! Map) return null;
  final synced = raw['syncedLyrics'];
  if (synced is String && synced.trim().isNotEmpty) {
    return LyricPayload(lyric: synced.trim());
  }
  final plain = raw['plainLyrics'];
  if (plain is String && plain.trim().isNotEmpty) {
    return LyricPayload(lyric: plain.trim());
  }
  return null;
}
