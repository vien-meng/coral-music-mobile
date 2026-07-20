import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../data/kuwo_lyric_service.dart';
import '../data/local_lyric_loader.dart';
import 'player_controller.dart';
import 'user_api_debug_controller.dart';

final _sessionLyricCacheProvider = Provider((_) => <String, LyricPayload>{});

final lyricProvider =
    FutureProvider.family<LyricPayload?, Track>((ref, track) async {
  ref.watch(userApiDebugProvider.select((state) => state.activeSourceId));
  ref.watch(userApiDebugProvider.select((state) => state.runtimeRevision));
  final local = await LocalLyricLoader().load(track);
  if (_hasContent(local) || track.sourceKind != TrackSourceKind.online) {
    return local;
  }

  final cache = ref.read(_sessionLyricCacheProvider);
  try {
    final lyric = await _loadOnlineLyric(
      track,
      ref.watch(userApiRunnerProvider).resolveLyric,
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
  } on AppFailure {
    final cached = cache[track.id];
    if (cached != null) return cached;
    rethrow;
  }
});

Future<LyricPayload?> _loadOnlineLyric(
  Track track,
  Future<LyricPayload?> Function(Track) resolveUserApi,
) async {
  AppFailure? builtInFailure;
  try {
    final lyric = await KuwoLyricService().resolve(track);
    if (_hasContent(lyric)) return lyric;
  } on AppFailure catch (error) {
    builtInFailure = error;
  }

  try {
    final lyric = await resolveUserApi(track);
    if (_hasContent(lyric)) return lyric;
  } on AppFailure catch (error) {
    if (builtInFailure == null) rethrow;
    throw AppFailure(
      code: error.code,
      message: '${builtInFailure.message}；${error.message}',
      diagnostic: [builtInFailure.diagnostic, error.diagnostic]
          .whereType<String>()
          .join(' | '),
    );
  }

  if (builtInFailure != null) throw builtInFailure;
  return null;
}

bool _hasContent(LyricPayload? lyric) =>
    lyric != null &&
    [lyric.lyric, lyric.lxlyric, lyric.tlyric, lyric.rlyric]
        .any((value) => value.trim().isNotEmpty);
