import 'dart:async';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/audio_engine.dart';
import 'package:coral_music_mobile/features/player/data/playback_resolver.dart';
import 'package:coral_music_mobile/features/player/data/user_api_runner.dart';
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

  test('resolves a User API URL before loading and playing the track',
      () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
    );

    await controller.playTrack(track);

    expect(engine.loadedUri, Uri.parse('https://example.com/audio.mp3'));
    expect(controller.state.track?.id, track.id);
    expect(controller.state.isPlaying, isTrue);
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
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

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
