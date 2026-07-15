import 'package:coral_music_mobile/core/http_client.dart';
import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/qq_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const enabled = bool.fromEnvironment('CORAL_LIVE_TEST');

  test(
    'QQ Music HTTPS leaderboard returns normalized tracks',
    () async {
      final service = QqCatalogService(createHttpClient());
      final boards = await service.getLeaderboardBoards(OnlineSource.qq);
      final result = await service.getLeaderboardDetail(
          OnlineSource.qq, boards.first.id, 1);
      expect(result.items, isNotEmpty);
      expect(result.items.first.sourceId, OnlineSource.qq.id);
    },
    skip: enabled ? false : 'Set CORAL_LIVE_TEST=true to call the live API.',
  );
}
