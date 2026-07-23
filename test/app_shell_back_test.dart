import 'package:coral_music_mobile/app/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the home branch exits to the launcher', () {
    expect(shouldMoveTaskToBack(0), isTrue);
    expect(shouldMoveTaskToBack(1), isFalse);
    expect(shouldMoveTaskToBack(2), isFalse);
  });
}
