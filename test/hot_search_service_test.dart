import 'package:coral_music_mobile/core/app_failure.dart';
import 'package:coral_music_mobile/features/search/data/hot_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses unique QQ MusicU hot terms and rejects malformed responses', () {
    expect(
      HotSearchService.parse({
        'code': 0,
        'hotkey': {
          'data': {
            'vec_hotkey': [
              {'query': '周杰伦'},
              {'query': '  林俊杰  '},
              {'query': '周杰伦'},
              {'query': ''},
            ],
          },
        },
      }),
      ['周杰伦', '林俊杰'],
    );
    expect(
      () => HotSearchService.parse({'code': 1}),
      throwsA(isA<AppFailure>()),
    );
  });
}
