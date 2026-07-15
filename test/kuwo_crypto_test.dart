import 'package:coral_music_mobile/features/leaderboard/data/kuwo_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds deterministic signed query and decrypts its payload', () {
    final query = KuwoCrypto.buildQuery(
      const {'id': '93', 'pn': 0, 'rn': 100},
      now: DateTime.fromMillisecondsSinceEpoch(1234567890),
    );
    final parameters = Uri.splitQueryString(query);

    expect(parameters['appId'], KuwoCrypto.appId);
    expect(parameters['time'], '1234567890');
    expect(parameters['sign'], hasLength(32));
    expect(KuwoCrypto.decodeResponse(parameters['data']!), {
      'id': '93',
      'pn': 0,
      'rn': 100,
    });
  });
}
