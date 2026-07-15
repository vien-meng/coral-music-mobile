import 'package:coral_music_mobile/core/http_client.dart';
import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/leaderboard/data/kuwo_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const enabled = bool.fromEnvironment('CORAL_LIVE_TEST');

  test(
    'Kuwo HTTPS search returns normalized tracks',
    () async {
      final result = await KuwoCatalogService(createHttpClient()).searchTracks(
        OnlineSource.kuwo,
        '周杰伦',
        1,
      );
      expect(result.items, isNotEmpty);
      expect(result.items.first.sourceId, OnlineSource.kuwo.id);
      expect(result.items.first.sourceTrackId, isNotEmpty);
    },
    skip: enabled ? false : 'Set CORAL_LIVE_TEST=true to call the live API.',
  );
}
