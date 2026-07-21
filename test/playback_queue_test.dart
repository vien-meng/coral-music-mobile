import 'dart:math';

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

  test('restored queue retains mode and safely clamps a stale index', () {
    final controller = PlaybackQueueController();

    controller.restoreQueue(
      tracks,
      currentIndex: 99,
      contextId: 'library:favorite',
      mode: PlaybackMode.shuffle,
    );

    expect(controller.state.currentTrack?.sourceTrackId, '2');
    expect(controller.state.contextId, 'library:favorite');
    expect(controller.state.mode, PlaybackMode.shuffle);
  });

  test('replacing the queue retains the selected playback mode', () {
    final controller = PlaybackQueueController()
      ..setMode(PlaybackMode.shuffle)
      ..replaceQueue(tracks, startIndex: 1);

    expect(controller.state.mode, PlaybackMode.shuffle);
  });

  test('replaces a queued track without changing the current selection', () {
    final controller = PlaybackQueueController()
      ..replaceQueue(tracks, startIndex: 1)
      ..replaceTrack(Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'kw',
        sourceTrackId: '1',
        title: '一',
        artist: '歌手',
        coverUri: Uri.parse('https://cover.example.com/1.jpg'),
      ));

    expect(controller.state.currentTrack?.sourceTrackId, '2');
    expect(controller.state.tracks.first.coverUri.toString(),
        'https://cover.example.com/1.jpg');
  });

  test('next and previous wrap at queue boundaries', () {
    final controller = PlaybackQueueController();
    controller.replaceQueue(tracks, startIndex: 0);

    expect(controller.selectPrevious()?.sourceTrackId, '2');
    expect(controller.selectNext()?.sourceTrackId, '1');
  });

  test('manual next and previous honor shuffle mode', () {
    const moreTracks = [
      ...tracks,
      Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'kw',
        sourceTrackId: '3',
        title: '三',
        artist: '歌手',
      ),
      Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'kw',
        sourceTrackId: '4',
        title: '四',
        artist: '歌手',
      ),
    ];
    PlaybackQueueController shuffledQueue() =>
        PlaybackQueueController(random: _MiddleRandom())
          ..replaceQueue(moreTracks)
          ..setMode(PlaybackMode.shuffle);

    expect(shuffledQueue().selectNext()?.sourceTrackId, '3');
    expect(shuffledQueue().selectPrevious()?.sourceTrackId, '3');
  });

  test('completion follows the selected playback mode', () {
    const third = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: '3',
      title: '三',
      artist: '歌手',
    );
    final controller = PlaybackQueueController()
      ..replaceQueue([...tracks, third]);

    controller.setMode(PlaybackMode.singleLoop);
    expect(controller.selectAfterCompletion()?.sourceTrackId, '1');

    controller.setMode(PlaybackMode.shuffle);
    final played = <String>{controller.state.currentTrack!.sourceTrackId};
    for (var index = 0; index < 2; index++) {
      played.add(controller.selectAfterCompletion()!.sourceTrackId);
    }
    expect(played, hasLength(3));

    controller.setMode(PlaybackMode.listLoop);
    controller.select(2);
    expect(controller.selectAfterCompletion()?.sourceTrackId, '1');
  });
}

final class _MiddleRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => .5;

  @override
  int nextInt(int max) => max ~/ 2;
}
