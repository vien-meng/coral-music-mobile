import 'dart:async';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/audio_engine.dart';
import 'package:coral_music_mobile/features/player/data/playback_resolver.dart';
import 'package:coral_music_mobile/features/player/data/user_api_runner.dart';
import 'package:coral_music_mobile/features/player/state/playback_queue_controller.dart';
import 'package:coral_music_mobile/features/player/state/player_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = Track(
    sourceKind: TrackSourceKind.online,
    sourceId: 'kw',
    sourceTrackId: '1',
    title: '测试歌曲',
    artist: '测试歌手',
  );
  const secondTrack = Track(
    sourceKind: TrackSourceKind.online,
    sourceId: 'kw',
    sourceTrackId: '2',
    title: '下一首测试歌曲',
    artist: '测试歌手',
  );

  test('resolves a User API URL before loading and playing the track',
      () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
      PlaybackQueueController(),
    );

    await controller.playTrack(track);

    expect(engine.loadedUri, Uri.parse('https://example.com/audio.mp3'));
    expect(controller.state.track?.id, track.id);
    expect(controller.state.isPlaying, isTrue);

    await controller.pause();
    await controller.toggle(track);

    expect(controller.state.isPlaying, isTrue);
  });

  test('loads and plays the next queued track after completion', () async {
    final engine = _FakeAudioEngine();
    final queue = PlaybackQueueController()
      ..replaceQueue(const [track, secondTrack]);
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
      queue,
    );

    await controller.playTrack(track);
    engine.complete(track);
    await Future<void>.delayed(Duration.zero);

    expect(queue.state.currentTrack?.id, secondTrack.id);
    expect(controller.state.track?.id, secondTrack.id);
    expect(controller.state.isPlaying, isTrue);
  });

  test('ignores a completed event from a track that is no longer current',
      () async {
    final engine = _FakeAudioEngine();
    final queue = PlaybackQueueController()
      ..replaceQueue(const [track, secondTrack]);
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
      queue,
    );

    await controller.playTrack(track);
    queue.selectNext();
    await controller.playTrack(secondTrack);
    engine.complete(track);
    await Future<void>.delayed(Duration.zero);

    expect(queue.state.currentTrack?.id, secondTrack.id);
    expect(controller.state.track?.id, secondTrack.id);
  });
}

final class _FakeAudioEngine implements AudioEngine {
  final _snapshots =
      StreamController<AudioEngineSnapshot>.broadcast(sync: true);
  Uri? loadedUri;
  Track? _track;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(Track track, Uri uri) async {
    _track = track;
    loadedUri = uri;
    _snapshots.add(
        AudioEngineSnapshot(track: track, status: AudioEngineStatus.ready));
  }

  @override
  Future<void> play() async => _snapshots.add(
        AudioEngineSnapshot(track: _track, status: AudioEngineStatus.playing),
      );

  @override
  Future<void> pause() async => _snapshots.add(
        AudioEngineSnapshot(track: _track, status: AudioEngineStatus.paused),
      );

  void complete(Track track) => _snapshots.add(
        AudioEngineSnapshot(track: track, status: AudioEngineStatus.completed),
      );

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _snapshots.close();
}

final class _FakeUserApiRunner implements UserApiRunner {
  @override
  Future<UserApiManifest> load(String script) async =>
      const UserApiManifest({'kw'});

  @override
  Future<Uri> resolveMusicUrl(Track track, AudioQuality quality) async =>
      Uri.parse('https://example.com/audio.mp3');
}
