import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/state/playback_queue_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tracks = [
    Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: '1',
      title: '一',
      artist: '歌手',
    ),
    Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: '2',
      title: '二',
      artist: '歌手',
    ),
  ];

  test('replace queue selects the requested track', () {
    final controller = PlaybackQueueController();

    controller.replaceQueue(tracks,
        startIndex: 1, contextId: 'leaderboard:test');

    expect(controller.state.currentTrack?.sourceTrackId, '2');
    expect(controller.state.contextId, 'leaderboard:test');
  });

  test('invalid queue index is rejected', () {
    final controller = PlaybackQueueController();

    expect(
        () => controller.replaceQueue(tracks, startIndex: 2), throwsRangeError);
  });

  test('next and previous wrap at queue boundaries', () {
    final controller = PlaybackQueueController();
    controller.replaceQueue(tracks, startIndex: 0);

    expect(controller.selectPrevious()?.sourceTrackId, '2');
    expect(controller.selectNext()?.sourceTrackId, '1');
  });
}
