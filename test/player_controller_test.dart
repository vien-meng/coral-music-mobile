import 'dart:async';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/audio_engine.dart';
import 'package:coral_music_mobile/features/player/data/playback_resolver.dart';
import 'package:coral_music_mobile/features/player/data/user_api_runner.dart';
import 'package:coral_music_mobile/features/player/state/playback_queue_controller.dart';
import 'package:coral_music_mobile/features/player/state/player_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    expect(engine.loadedUri, Uri.parse('https://example.com/1.mp3'));
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

  test('ignores a stale playback URL after the user selects another track',
      () async {
    final engine = _FakeAudioEngine();
    final runner = _DeferredUserApiRunner();
    final controller = PlayerController(
      engine,
      PlaybackResolver(runner),
      PlaybackQueueController(),
    );

    final firstRequest = controller.playTrack(track);
    await Future<void>.delayed(Duration.zero);
    final secondRequest = controller.playTrack(secondTrack);
    await Future<void>.delayed(Duration.zero);
    runner.complete(secondTrack, Uri.parse('https://example.com/second.mp3'));
    await secondRequest;
    runner.complete(track, Uri.parse('https://example.com/first.mp3'));
    await firstRequest;

    expect(engine.loadedUri, Uri.parse('https://example.com/second.mp3'));
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

  test('refreshes the URL once when audio loading fails', () async {
    final engine = _FakeAudioEngine(failures: 1);
    final runner = _FakeUserApiRunner();
    final controller = PlayerController(
      engine,
      PlaybackResolver(runner),
      PlaybackQueueController(),
    );

    await controller.playTrack(track);
    await Future<void>.delayed(Duration.zero);

    expect(engine.loadCount, 2);
    expect(runner.resolveCount, 2);
    expect(controller.state.isPlaying, isTrue);
  });

  test('falls back to the next declared quality after a refreshed URL fails',
      () async {
    const qualityTrack = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: 'quality',
      title: '音质测试',
      artist: '测试歌手',
      availableQualities: [
        AudioQuality.high320k,
        AudioQuality.standard128k,
      ],
    );
    final engine = _FakeAudioEngine(failures: 2);
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
      PlaybackQueueController(),
    );

    await controller.playTrack(qualityTrack, quality: AudioQuality.high320k);
    await Future<void>.delayed(Duration.zero);

    expect(engine.loadCount, 3);
    expect(controller.state.quality, AudioQuality.standard128k);
  });

  test(
      'keeps a paused track position and player settings when changing quality',
      () async {
    const qualityTrack = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: 'quality-switch',
      title: '音质切换测试',
      artist: '测试歌手',
      availableQualities: [
        AudioQuality.high320k,
        AudioQuality.standard128k,
      ],
    );
    final engine = _FakeAudioEngine();
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
      PlaybackQueueController(),
    );

    await controller.playTrack(qualityTrack, quality: AudioQuality.high320k);
    await controller.setSpeed(1.25);
    await controller.setVolume(.6);
    await controller.seek(const Duration(seconds: 42));
    await controller.pause();
    await controller.setQuality(AudioQuality.standard128k);

    expect(engine.seekPosition, const Duration(seconds: 42));
    expect(controller.state.status, AudioEngineStatus.ready);
    expect(controller.state.quality, AudioQuality.standard128k);
    expect(controller.state.speed, 1.25);
    expect(controller.state.volume, .6);
  });

  test('resumes a history track only after the first five seconds', () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
      PlaybackQueueController(),
    );

    await controller.playTrack(
      track,
      initialPosition: const Duration(seconds: 42),
    );
    expect(engine.seekPosition, const Duration(seconds: 42));

    engine.seekPosition = null;
    await controller.playTrack(
      track,
      initialPosition: const Duration(seconds: 4),
    );
    expect(engine.seekPosition, isNull);
  });

  test('routes background next commands through the playback queue', () async {
    final engine = _FakeAudioEngine();
    final queue = PlaybackQueueController()
      ..replaceQueue(const [track, secondTrack]);
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
      queue,
    );

    await controller.playTrack(track);
    engine.command(AudioEngineCommand.next);
    await Future<void>.delayed(Duration.zero);

    expect(queue.state.currentTrack?.id, secondTrack.id);
    expect(controller.state.track?.id, secondTrack.id);
  });
}

final class _FakeAudioEngine implements AudioEngine {
  _FakeAudioEngine({this.failures = 0});

  final _snapshots =
      StreamController<AudioEngineSnapshot>.broadcast(sync: true);
  final _commands = StreamController<AudioEngineCommand>.broadcast(sync: true);
  final int failures;
  Uri? loadedUri;
  Track? _track;
  var loadCount = 0;
  Duration? seekPosition;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<AudioEngineCommand> get commands => _commands.stream;

  @override
  Future<void> load(Track track, Uri uri) async {
    loadCount++;
    if (loadCount <= failures) throw StateError('临时地址已过期');
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

  void command(AudioEngineCommand command) => _commands.add(command);

  @override
  Future<void> seek(Duration position) async => seekPosition = position;

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _commands.close();
  }
}

final class _FakeUserApiRunner implements UserApiRunner {
  var resolveCount = 0;
  @override
  Future<UserApiManifest> load(String script) async =>
      const UserApiManifest({'kw'});

  @override
  Future<void> clear() async {}

  @override
  Future<LyricPayload?> resolveLyric(Track track) async => null;

  @override
  Future<Uri> resolveMusicUrl(Track track, AudioQuality quality) async {
    resolveCount++;
    return Uri.parse('https://example.com/$resolveCount.mp3');
  }
}

final class _DeferredUserApiRunner implements UserApiRunner {
  final _responses = <String, Completer<Uri>>{};

  @override
  Future<void> clear() async {}

  void complete(Track track, Uri uri) =>
      (_responses[track.id] ??= Completer<Uri>()).complete(uri);

  @override
  Future<LyricPayload?> resolveLyric(Track track) async => null;

  @override
  Future<UserApiManifest> load(String script) async =>
      const UserApiManifest({'kw'});

  @override
  Future<Uri> resolveMusicUrl(Track track, AudioQuality quality) =>
      (_responses[track.id] ??= Completer<Uri>()).future;
}
