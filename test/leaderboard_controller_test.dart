import 'dart:async';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/online_catalog_service.dart';
import 'package:coral_music_mobile/features/leaderboard/state/leaderboard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stale response cannot overwrite the newest board', () async {
    final service = _DelayedCatalogService();
    final controller = LeaderboardController(service);
    final first = service.boards[0];
    final second = service.boards[1];

    final firstRequest = controller.selectBoard(first);
    final secondRequest = controller.selectBoard(second);
    service.second.complete(_page('second'));
    await secondRequest;
    service.first.complete(_page('first'));
    await firstRequest;

    expect(controller.state.activeBoard?.id, second.id);
    expect(controller.state.tracks.single.sourceTrackId, 'second');
  });
}

PageResult<Track> _page(String id) => PageResult(
      items: [
        Track(
          sourceKind: TrackSourceKind.online,
          sourceId: 'kw',
          sourceTrackId: id,
          title: id,
          artist: 'artist',
        ),
      ],
      page: 1,
      pageSize: 100,
      total: 1,
    );

final class _DelayedCatalogService implements OnlineCatalogService {
  final boards = const [
    LeaderboardBoard(
      id: 'first',
      source: OnlineSource.kuwo,
      name: 'first',
      remoteId: '1',
    ),
    LeaderboardBoard(
      id: 'second',
      source: OnlineSource.kuwo,
      name: 'second',
      remoteId: '2',
    ),
  ];
  final first = Completer<PageResult<Track>>();
  final second = Completer<PageResult<Track>>();

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(
          OnlineSource source) async =>
      boards;

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  ) =>
      boardId == 'first' ? first.future : second.future;

  @override
  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  ) =>
      Future.value(_page(query));
}
