import 'package:coral_music_mobile/domain/music.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('track id is stable and source-qualified', () {
    const track = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: '123',
      title: '同名歌曲',
      artist: '歌手',
    );

    expect(track.id, 'online:kw:123');
  });

  test('page result exposes pagination boundaries', () {
    const result =
        PageResult<int>(items: [1], page: 2, pageSize: 10, total: 21);

    expect(result.hasPrevious, isTrue);
    expect(result.hasNext, isTrue);
  });
}
