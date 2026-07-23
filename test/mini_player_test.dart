import 'dart:async';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/audio_engine.dart';
import 'package:coral_music_mobile/features/player/state/playback_queue_controller.dart';
import 'package:coral_music_mobile/features/player/state/player_controller.dart';
import 'package:coral_music_mobile/features/player/view/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the direct-debug track and its seek control',
      (tester) async {
    final engine = _DebugAudioEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioEngineProvider.overrideWithValue(engine)],
        child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MiniPlayer)),
    );
    await container
        .read(playerProvider.notifier)
        .playDebugUrl('https://example.com/audio.mp3');
    await tester.pump();

    expect(find.text('调试音频'), findsOneWidget);
    expect(find.text('example.com · 正在播放'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('plays the previous and next queued tracks', (tester) async {
    final engine = _DebugAudioEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioEngineProvider.overrideWithValue(engine)],
        child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MiniPlayer)),
    );
    final first = Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'local',
      sourceTrackId: '1',
      title: '第一首',
      artist: '珊瑚音乐',
      localUri: Uri.file('/tmp/first.mp3'),
    );
    final second = Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'local',
      sourceTrackId: '2',
      title: '第二首',
      artist: '珊瑚音乐',
      localUri: Uri.file('/tmp/second.mp3'),
    );
    container
        .read(playbackQueueProvider.notifier)
        .replaceQueue([first, second]);
    await container.read(playerProvider.notifier).playTrack(first);
    await tester.pump();

    expect(find.byTooltip('上一曲'), findsOneWidget);
    expect(find.byTooltip('下一曲'), findsOneWidget);

    await tester.tap(find.byTooltip('下一曲'));
    await tester.pump();
    expect(find.text('第二首'), findsOneWidget);

    await tester.tap(find.byTooltip('上一曲'));
    await tester.pump();
    expect(find.text('第一首'), findsOneWidget);
  });
}

final class _DebugAudioEngine implements AudioEngine {
  final _snapshots =
      StreamController<AudioEngineSnapshot>.broadcast(sync: true);
  Track? _track;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<AudioEngineCommand> get commands => const Stream.empty();

  @override
  Future<void> dispose() => _snapshots.close();

  @override
  Future<void> load(Track track, Uri uri,
      {Map<String, String> headers = const {}}) async {
    _track = track;
    _snapshots.add(
      AudioEngineSnapshot(
        track: track,
        duration: const Duration(minutes: 3),
        status: AudioEngineStatus.ready,
      ),
    );
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async => _snapshots.add(
        AudioEngineSnapshot(
          track: _track,
          duration: const Duration(minutes: 3),
          status: AudioEngineStatus.playing,
        ),
      );

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}
