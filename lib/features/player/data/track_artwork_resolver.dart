import '../../../domain/music.dart';
import '../../leaderboard/data/online_catalog_service.dart';

/// Resolves missing cover artwork for a [Track] by searching the track's
/// online source and borrowing the first matching result's cover URI.
final class TrackArtworkResolver {
  const TrackArtworkResolver(this._services);

  final Map<OnlineSource, OnlineCatalogService> _services;

  Future<Uri?> resolve(Track track) async {
    if (track.coverUri != null) return track.coverUri;
    if (track.sourceKind != TrackSourceKind.online) return null;
    final source = _sourceFor(track.sourceId);
    if (source == null) return null;
    final service = _services[source];
    if (service == null) return null;
    final query = '${track.title} ${track.artist}'.trim();
    if (query.isEmpty) return null;
    try {
      final result = await service.searchTracks(source, query, 1);
      for (final candidate in result.items) {
        if (candidate.coverUri != null) return candidate.coverUri;
      }
    } on Object {
      // Best-effort artwork lookup; failures are not user-facing.
    }
    return null;
  }

  static OnlineSource? _sourceFor(String sourceId) => switch (sourceId) {
        'kw' => OnlineSource.kuwo,
        'kg' => OnlineSource.kugou,
        'tx' => OnlineSource.qq,
        'wy' => OnlineSource.netease,
        'mg' => OnlineSource.migu,
        _ => null,
      };
}
