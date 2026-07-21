import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import '../data/kuwo_lyric_service.dart';
import '../data/lrclib_lyric_service.dart';
import '../data/local_lyric_loader.dart';
import '../data/source_lyric_service.dart';

final _sessionLyricCacheProvider = Provider((_) => <String, LyricPayload>{});
final lyricFallbackProvider = Provider<Future<LyricPayload?> Function(Track)>(
    (_) => LrcLibLyricService(createHttpClient()).resolve);
final sourceLyricProvider = Provider<Future<LyricPayload?> Function(Track)>(
    (_) => SourceLyricService(createHttpClient()).resolve);

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
    ref.read(sourceLyricProvider),
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
  Future<LyricPayload?> Function(Track) resolveSource,
  Future<LyricPayload?> Function(Track) resolveFallback,
) async {
  try {
    final lyric = await KuwoLyricService().resolve(track);
    if (_hasContent(lyric)) return lyric;
  } on Object {
    // Continue to the independent backend when a source-specific endpoint
    // changes format or is temporarily unavailable.
  }

  try {
    final lyric = await resolveSource(track);
    if (_hasContent(lyric)) return lyric;
  } on Object {
    // Continue to the independent keyword service when source metadata is stale.
  }

  try {
    final lyric = await resolveFallback(track);
    if (_hasContent(lyric)) return lyric;
  } on Object {
    // Keep the empty state retryable; never surface backend implementation
    // messages such as "action not support" to the user.
  }
  return null;
}

bool _hasContent(LyricPayload? lyric) =>
    lyric != null &&
    [lyric.lyric, lyric.lxlyric, lyric.tlyric, lyric.rlyric]
        .any((value) => value.trim().isNotEmpty);
