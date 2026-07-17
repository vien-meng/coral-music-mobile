import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import 'user_api_runner.dart';

final class PlaybackResolver {
  PlaybackResolver(this._userApiRunner);

  final UserApiRunner _userApiRunner;
  final _cachedUrls = <String, _CachedPlaybackUrl>{};

  static const _urlCacheLifetime = Duration(minutes: 15);

  Future<Uri> resolve(
    Track track, {
    AudioQuality? quality,
    bool forceRefresh = false,
  }) async {
    if (track.sourceKind != TrackSourceKind.online) {
      final uri = track.localUri;
      if (uri != null) return uri;
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
      return cached.uri;
    }
    final uri = await _userApiRunner.resolveMusicUrl(track, resolvedQuality);
    _cachedUrls[key] = _CachedPlaybackUrl(
      uri: uri,
      expiresAt: DateTime.now().add(_urlCacheLifetime),
    );
    return uri;
  }

  void invalidate(Track track, {AudioQuality? quality}) {
    final resolvedQuality =
        quality ?? defaultPlaybackQuality(track.availableQualities);
    _cachedUrls.remove(_cacheKey(track, resolvedQuality));
  }

  String _cacheKey(Track track, AudioQuality quality) =>
      '${track.id}:${quality.name}';
}

final class _CachedPlaybackUrl {
  const _CachedPlaybackUrl({required this.uri, required this.expiresAt});

  final Uri uri;
  final DateTime expiresAt;
}
