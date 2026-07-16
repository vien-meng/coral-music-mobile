import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/online_catalog_service.dart';

final class FakeCatalogService implements OnlineCatalogService {
  static const board = LeaderboardBoard(
    id: 'kw__test',
    source: OnlineSource.kuwo,
    name: '测试榜单',
    remoteId: 'test',
  );

  static const track = Track(
    sourceKind: TrackSourceKind.online,
    sourceId: 'kw',
    sourceTrackId: 'track-1',
    title: '测试歌曲',
    artist: '测试歌手',
    duration: Duration(minutes: 3),
  );

  static const qqBoard = LeaderboardBoard(
    id: 'tx__test',
    source: OnlineSource.qq,
    name: 'QQ 测试榜单',
    remoteId: 'test',
  );

  static const qqTrack = Track(
    sourceKind: TrackSourceKind.online,
    sourceId: 'tx',
    sourceTrackId: 'qq-track-1',
    title: 'QQ 测试歌曲',
    artist: 'QQ 测试歌手',
    duration: Duration(minutes: 4),
  );

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(
          OnlineSource source) async =>
      source == OnlineSource.qq ? [qqBoard] : [board];

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  ) async =>
      PageResult(
        items: source == OnlineSource.qq ? const [qqTrack] : const [track],
        page: page,
        pageSize: 100,
        total: 1,
      );

  @override
  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  ) async =>
      PageResult(items: const [track], page: page, pageSize: 30, total: 1);
}
