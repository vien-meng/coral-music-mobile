import '../../../core/app_failure.dart';
import '../../../domain/music.dart';

abstract interface class OnlineCatalogService {
  Future<List<LeaderboardBoard>> getLeaderboardBoards(OnlineSource source);

  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  );

  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  );
}

final class MultiSourceOnlineCatalogService implements OnlineCatalogService {
  const MultiSourceOnlineCatalogService(this._services);

  final Map<OnlineSource, OnlineCatalogService> _services;

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(OnlineSource source) =>
      _forSource(source).getLeaderboardBoards(source);

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  ) =>
      _forSource(source).getLeaderboardDetail(source, boardId, page);

  @override
  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  ) =>
      _forSource(source).searchTracks(source, query, page);

  OnlineCatalogService _forSource(OnlineSource source) {
    final service = _services[source];
    if (service == null) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: '${source.label}暂未接入',
      );
    }
    return service;
  }
}
