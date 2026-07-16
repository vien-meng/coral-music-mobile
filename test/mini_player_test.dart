import 'dart:async';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/audio_engine.dart';
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
}

final class _DebugAudioEngine implements AudioEngine {
  final _snapshots =
      StreamController<AudioEngineSnapshot>.broadcast(sync: true);
  Track? _track;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> dispose() => _snapshots.close();

  @override
  Future<void> load(Track track, Uri uri) async {
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
