import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/library/data/playlist_duplicates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Track track(String id, {String album = '专辑', int? seconds = 180}) => Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'kw',
        sourceTrackId: id,
        title: ' 同一首歌 ',
        artist: '歌手',
        album: album,
        duration: seconds == null ? null : Duration(seconds: seconds),
      );

  test('keeps the first exact metadata match and selects later duplicates', () {
    expect(
      findDuplicateTrackIds([track('1'), track('2'), track('3', album: '别的')]),
      {'online:kw:2'},
    );
  });

  test('does not guess when duration is unavailable', () {
    expect(
        findDuplicateTrackIds(
            [track('1', seconds: null), track('2', seconds: null)]),
        isEmpty);
  });
}
