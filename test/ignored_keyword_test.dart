import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/library/data/library_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = Track(
    sourceKind: TrackSourceKind.online,
    sourceId: 'kw',
    sourceTrackId: '1',
    title: 'Live Version',
    artist: 'Coral Band',
    album: 'Summer',
  );

  test('matches title artist and album case-insensitively', () {
    expect(matchesIgnoredKeyword(track, 'live'), isTrue);
    expect(matchesIgnoredKeyword(track, 'CORAL'), isTrue);
    expect(matchesIgnoredKeyword(track, 'summer'), isTrue);
    expect(matchesIgnoredKeyword(track, 'studio'), isFalse);
  });
}
