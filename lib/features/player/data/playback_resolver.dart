import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../../webdav/data/webdav_credentials.dart';
import 'user_api_runner.dart';

final class PlaybackResolver {
  PlaybackResolver(this._userApiRunner, [WebDavCredentials? webDavCredentials])
      : _webDavCredentials = webDavCredentials ?? WebDavCredentials();

  final UserApiRunner _userApiRunner;
  final WebDavCredentials _webDavCredentials;
  final _cachedUrls = <String, _CachedPlaybackUrl>{};
  Future<void>? _userApiInitialization;

  static const _urlCacheLifetime = Duration(minutes: 15);

  /// The persisted User API script loads asynchronously at launch. Online
  /// requests must not race the WebView reset performed by that load.
  void setUserApiInitialization(Future<void> initialization) {
    _userApiInitialization = initialization;
  }

  Future<ResolvedPlaybackUrl> resolve(
    Track track, {
    AudioQuality? quality,
    bool forceRefresh = false,
  }) async {
    if (track.sourceKind == TrackSourceKind.webdav) {
      final uri = track.localUri;
      final authorization = await _webDavCredentials.read(track.sourceId);
      if (uri != null && authorization != null && authorization.isNotEmpty) {
        return ResolvedPlaybackUrl(uri,
            headers: {'Authorization': authorization});
      }
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'WebDAV 凭据已失效，请重新连接',
      );
    }
    if (track.sourceKind != TrackSourceKind.online) {
      final uri = track.localUri;
      if (uri != null) return ResolvedPlaybackUrl(uri);
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '该来源缺少播放地址',
      );
    }
    await _userApiInitialization;
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
