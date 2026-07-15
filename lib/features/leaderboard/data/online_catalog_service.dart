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
