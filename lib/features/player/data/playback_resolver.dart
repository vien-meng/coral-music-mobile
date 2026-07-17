import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import 'user_api_runner.dart';

final class PlaybackResolver {
  PlaybackResolver(this._userApiRunner);

  final UserApiRunner _userApiRunner;
  final _cachedUrls = <String, _CachedPlaybackUrl>{};

  static const _urlCacheLifetime = Duration(minutes: 15);

  Future<ResolvedPlaybackUrl> resolve(
    Track track, {
    AudioQuality? quality,
    bool forceRefresh = false,
  }) async {
    if (track.sourceKind != TrackSourceKind.online) {
      final uri = track.localUri;
      if (uri != null) return ResolvedPlaybackUrl(uri);
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '该来源缺少播放地址',
      );
    }
    final resolvedQuality =
        quality ?? defaultPlaybackQuality(track.availableQualities);
    final key = _cacheKey(track, resolvedQuality);
    final cached = _cachedUrls[key];
    if (!forceRefresh &&
        cached != null &&
        cached.expiresAt.isAfter(DateTime.now())) {
      return cached.playbackUrl;
    }
    final playbackUrl =
        await _userApiRunner.resolveMusicUrl(track, resolvedQuality);
    _cachedUrls[key] = _CachedPlaybackUrl(
      playbackUrl: playbackUrl,
      expiresAt: DateTime.now().add(_urlCacheLifetime),
    );
    return playbackUrl;
  }

  void invalidate(Track track, {AudioQuality? quality}) {
    final resolvedQuality =
        quality ?? defaultPlaybackQuality(track.availableQualities);
    _cachedUrls.remove(_cacheKey(track, resolvedQuality));
    _cachedUrls.removeWhere(
      (key, cached) =>
          key.startsWith('${track.id}:') &&
          cached.playbackUrl.quality == resolvedQuality,
    );
  }

  void clear() => _cachedUrls.clear();

  String _cacheKey(Track track, AudioQuality quality) =>
      '${track.id}:${quality.name}';
}

final class _CachedPlaybackUrl {
  const _CachedPlaybackUrl({
    required this.playbackUrl,
    required this.expiresAt,
  });

  final ResolvedPlaybackUrl playbackUrl;
  final DateTime expiresAt;
}
