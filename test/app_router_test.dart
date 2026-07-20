import 'package:coral_music_mobile/app/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes both supported Coral Music player links', () {
    expect(
      normalizeCoralMusicDeepLink(Uri.parse('coralmusic:///player')),
      '/player',
    );
    expect(
      normalizeCoralMusicDeepLink(Uri.parse('coralmusic://player')),
      '/player',
    );
  });

  test('does not redirect ordinary routes and safely falls back unknown links',
      () {
    expect(normalizeCoralMusicDeepLink(Uri.parse('/search')), isNull);
    expect(
      normalizeCoralMusicDeepLink(Uri.parse('coralmusic://unsupported')),
      '/leaderboard',
    );
  });
}
