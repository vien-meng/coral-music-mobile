import 'package:coral_music_mobile/core/http_client.dart';
import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/kuwo_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const enabled = bool.fromEnvironment('CORAL_LIVE_TEST');

  test(
    'loads the first Kuwo leaderboard from the live service',
    () async {
      final service = KuwoCatalogService(createHttpClient());
      final boards = await service.getLeaderboardBoards(OnlineSource.kuwo);
      final page = await service.getLeaderboardDetail(
        OnlineSource.kuwo,
        boards.first.id,
        1,
      );

      expect(page.items, isNotEmpty);
      expect(page.items.first.sourceId, OnlineSource.kuwo.id);
    },
    skip: enabled ? false : 'set CORAL_LIVE_TEST=true to call the live service',
  );
}
