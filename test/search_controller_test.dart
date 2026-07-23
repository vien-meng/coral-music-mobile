import 'dart:async';

import 'package:coral_music_mobile/core/app_failure.dart';
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

  test('keeps recent keywords unique and clears persisted history', () async {
    final service = _DelayedSearchCatalogService();
    final recorded = <String>[];
    var cleared = false;
    final controller = SearchController(
      service,
      loadHistory: () async => const ['旧关键词'],
      recordHistory: (keyword) async => recorded.add(keyword),
      clearHistory: () async => cleared = true,
    );
    await Future<void>.delayed(Duration.zero);

    final first = controller.submit('新关键词');
    service.second.complete(_page('new'));
    await first;
    final second = controller.submit('新关键词');
    await second;

    expect(controller.state.history, ['新关键词', '旧关键词']);
    expect(recorded, ['新关键词', '新关键词']);
    await controller.clearHistory();
    expect(controller.state.history, isEmpty);
    expect(cleared, isTrue);
  });

  test('combined search keeps successful source results when one fails',
      () async {
    final controller = SearchController(_DelayedSearchCatalogService());

    await controller.selectCombined();
    await controller.submit('combined');

    expect(controller.state.isCombined, isTrue);
    expect(
      controller.state.tracks.map((track) => track.sourceTrackId),
      ['kw', 'kg', 'qq', 'mg'],
    );
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
  ) {
    if (query == 'combined') {
      return switch (source) {
        OnlineSource.kuwo => Future.value(_page('kw')),
        OnlineSource.kugou => Future.value(_page('kg')),
        OnlineSource.qq => Future.value(_page('qq')),
        OnlineSource.netease => Future.error(const AppFailure(
            code: AppFailureCode.noNetwork,
            message: '网易云不可用',
          )),
        OnlineSource.migu => Future.value(_page('mg')),
      };
    }
    return query == 'first' ? first.future : second.future;
  }
}
