import 'dart:async';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/online_catalog_service.dart';
import 'package:coral_music_mobile/features/search/state/search_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stale search response cannot overwrite the newest query', () async {
    final service = _DelayedSearchCatalogService();
    final controller = SearchController(service);

    final firstRequest = controller.submit('first');
    final secondRequest = controller.submit('second');
    service.second.complete(_page('second'));
    await secondRequest;
    service.first.complete(_page('first'));
    await firstRequest;

    expect(controller.state.query, 'second');
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
      pageSize: 30,
      total: 1,
    );

final class _DelayedSearchCatalogService implements OnlineCatalogService {
  final first = Completer<PageResult<Track>>();
  final second = Completer<PageResult<Track>>();

  @override
  Future<List<LeaderboardBoard>> getLeaderboardBoards(OnlineSource source) =>
      Future.value(const []);

  @override
  Future<PageResult<Track>> getLeaderboardDetail(
    OnlineSource source,
    String boardId,
    int page,
  ) =>
      Future.value(_page(boardId));

  @override
  Future<PageResult<Track>> searchTracks(
    OnlineSource source,
    String query,
    int page,
  ) =>
      query == 'first' ? first.future : second.future;
}
