import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/online_catalog_service.dart';
import 'package:coral_music_mobile/features/leaderboard/state/leaderboard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('switching source reloads its first board and tracks', () async {
    final controller = LeaderboardController(_SourceCatalogService());

    await controller.selectSource(OnlineSource.qq);

    expect(controller.state.source, OnlineSource.qq);
    expect(controller.state.activeBoard?.id, 'tx__test');
    expect(controller.state.tracks.single.sourceId, OnlineSource.qq.id);
  });
}

final class _SourceCatalogService implements OnlineCatalogService {
  static const _qqBoard = LeaderboardBoard(
    id: 'tx__test',
    source: OnlineSource.qq,
    name: 'QQ 测试榜',
    remoteId: 'test',
  );

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(
          OnlineSource source) async =>
      source == OnlineSource.qq ? const [_qqBoard] : const [];

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  ) async =>
      PageResult(
        items: [
          Track(
            sourceKind: TrackSourceKind.online,
            sourceId: source.id,
            sourceTrackId: 'track',
            title: '测试歌曲',
            artist: '测试歌手',
          ),
        ],
        page: 1,
        pageSize: 1,
        total: 1,
      );

  @override
  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  ) =>
      throw UnimplementedError();
}
