import 'package:coral_music_mobile/core/app_failure.dart';
import 'package:coral_music_mobile/core/http_client.dart';
import 'package:coral_music_mobile/features/player/data/user_api_script_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects non-HTTPS User API script URLs before requesting them',
      () async {
    final fetcher = UserApiScriptFetcher(createHttpClient());

    await expectLater(
      fetcher.fetch(Uri.parse('http://example.com/source.js')),
      throwsA(isA<AppFailure>()),
    );
  });
}
