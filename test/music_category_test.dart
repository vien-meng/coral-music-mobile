import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/library/view/history_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups the same artist tracks without dropping their queue order', () {
    const first = Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'device',
      sourceTrackId: '1',
      title: '一',
      artist: '歌手',
    );
    const second = Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'device',
      sourceTrackId: '2',
      title: '二',
      artist: '歌手',
    );

    final groups = groupTracksBy([first, second], (track) => track.artist);

    expect(groups.keys, ['歌手']);
    expect(groups['歌手'], [first, second]);
  });

  test('keeps imported genre and year tags available to classification', () {
    const track = Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'device',
      sourceTrackId: 'metadata',
      title: '夜航',
      artist: '珊瑚',
      extra: {'genre': '电子', 'year': '2025'},
    );

    expect(
        groupTracksBy([track], (item) => item.extra['genre']! as String).keys,
        ['电子']);
    expect(groupTracksBy([track], (item) => item.extra['year']! as String).keys,
        ['2025']);
  });
}
