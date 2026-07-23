import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../data/independent_lyric_service.dart';
import '../data/local_lyric_loader.dart';

final _sessionLyricCacheProvider = Provider((_) => <String, LyricPayload>{});
final lyricFallbackProvider = Provider<Future<LyricPayload?> Function(Track)>(
    (_) => IndependentLyricService(_createLyricHttpClient()).resolve);

Dio _createLyricHttpClient() => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              'Chrome/120 Mobile Safari/537.36',
        },
      ),
    );
final lyricProvider =
    FutureProvider.family<LyricPayload?, Track>((ref, track) async {
  final local = await LocalLyricLoader().load(track);
  if (_hasContent(local)) return local;
  if (track.sourceKind != TrackSourceKind.online &&
      track.sourceKind != TrackSourceKind.local) {
    return local;
  }

  final cache = ref.read(_sessionLyricCacheProvider);
  final lyric = await _loadOnlineLyric(
    track,
    ref.read(lyricFallbackProvider),
  );
  if (_hasContent(lyric)) {
    // ponytail: 20-track session FIFO; persist lyrics when offline access is required.
    if (cache.length >= 20 && !cache.containsKey(track.id)) {
      cache.remove(cache.keys.first);
    }
    cache[track.id] = lyric!;
    return lyric;
  }
  return cache[track.id];
});

Future<LyricPayload?> _loadOnlineLyric(
  Track track,
  Future<LyricPayload?> Function(Track) resolveFallback,
) async {
  try {
    final lyric = await resolveFallback(track);
    if (_hasContent(lyric)) return lyric;
  } on Object {
    // Keep the independent lookup retryable; service errors are not user-facing.
  }
  return null;
}

bool _hasContent(LyricPayload? lyric) =>
    lyric != null &&
    [lyric.lyric, lyric.lxlyric, lyric.tlyric, lyric.rlyric]
        .any((value) => value.trim().isNotEmpty);
