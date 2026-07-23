import 'dart:async';

import 'package:coral_music_mobile/core/app_failure.dart';
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

  test('handles duplicate completion snapshots once in every playback mode',
      () async {
    for (final mode in PlaybackMode.values) {
      final engine = _FakeAudioEngine();
      final runner = _FakeUserApiRunner();
      final queue = PlaybackQueueController()
        ..replaceQueue(const [track, secondTrack])
        ..setMode(mode);
      final controller = PlayerController(
        engine,
        PlaybackResolver(runner),
        queue,
      );

      await controller.playTrack(track);
      engine
        ..complete(track)
        ..complete(track);
      await Future<void>.delayed(Duration.zero);

      expect(runner.resolveCount, 2, reason: mode.name);
      expect(
        controller.state.track?.id,
        mode == PlaybackMode.singleLoop ? track.id : secondTrack.id,
        reason: mode.name,
      );
    }
  });

  test('stops instead of advancing when current-track sleep stop is enabled',
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
    controller.setStopAfterCurrent(true);
    engine.complete(track);
    await Future<void>.delayed(Duration.zero);

    expect(queue.state.currentTrack?.id, track.id);
    expect(engine.stopCount, 1);
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

  test('forces a fresh URL when retrying the current track', () async {
    final engine = _FakeAudioEngine();
    final runner = _FakeUserApiRunner();
    final controller = PlayerController(
      engine,
      PlaybackResolver(runner),
      PlaybackQueueController(),
    );

    await controller.playTrack(track);
    await controller.retryCurrent();

    expect(runner.resolveCount, 2);
    expect(engine.loadedUri, Uri.parse('https://example.com/2.mp3'));
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

  test('falls back from SQ to HQ when FLAC URL resolution fails', () async {
    const qualityTrack = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: 'resolver-quality',
      title: '取链降级测试',
      artist: '测试歌手',
      availableQualities: [AudioQuality.flac, AudioQuality.high320k],
    );
    final runner = _QualityFallbackRunner();
    final controller = PlayerController(
      _FakeAudioEngine(),
      PlaybackResolver(runner),
      PlaybackQueueController(),
    );

    await controller.playTrack(qualityTrack);
    await Future<void>.delayed(Duration.zero);

    expect(runner.qualities, [AudioQuality.flac, AudioQuality.high320k]);
    expect(controller.state.quality, AudioQuality.high320k);
    expect(controller.state.isPlaying, isTrue);
  });

  test('uses the persisted default quality for a new playback request',
      () async {
    const qualityTrack = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: 'preferred-quality',
      title: '默认音质测试',
      artist: '测试歌手',
      availableQualities: [
        AudioQuality.flac,
        AudioQuality.high320k,
        AudioQuality.standard128k,
      ],
    );
    final runner = _QualityFallbackRunner();
    final controller = PlayerController(
      _FakeAudioEngine(),
      PlaybackResolver(runner),
      PlaybackQueueController(),
    );

    controller.setDefaultQuality(AudioQuality.high320k);
    await controller.playTrack(qualityTrack);

    expect(runner.qualities, [AudioQuality.high320k]);
    expect(controller.state.quality, AudioQuality.high320k);
  });

  test('shows the actual quality returned by the source', () async {
    final controller = PlayerController(
      _FakeAudioEngine(),
      PlaybackResolver(_ActualQualityRunner()),
      PlaybackQueueController(),
    );

    await controller.playTrack(track);

    expect(controller.state.quality, AudioQuality.high320k);
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

  test('restores the latest history item without loading audio at launch',
      () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
      PlaybackQueueController(),
      null,
      null,
      null,
      () async => [
        PlayHistoryEntry(
          track: track,
          playedAt: DateTime(2026),
          playCount: 1,
          lastPosition: const Duration(seconds: 42),
        ),
      ],
    );

    await controller.restoreLastPlayback();

    expect(controller.state.track, track);
    expect(controller.state.position, const Duration(seconds: 42));
    expect(controller.state.status, AudioEngineStatus.idle);
    expect(engine.loadCount, 0);

    await controller.toggle(track);
    expect(engine.seekPosition, const Duration(seconds: 42));
    expect(controller.state.isPlaying, isTrue);
  });

  test('normalizes a near-start history position when restoring at launch',
      () async {
    final controller = PlayerController(
      _FakeAudioEngine(),
      PlaybackResolver(_FakeUserApiRunner()),
      PlaybackQueueController(),
      null,
      null,
      null,
      () async => [
        PlayHistoryEntry(
          track: track,
          playedAt: DateTime(2026),
          playCount: 1,
          lastPosition: const Duration(seconds: 4),
        ),
      ],
    );

    await controller.restoreLastPlayback();

    expect(controller.state.position, Duration.zero);
  });

  test('clamps application speed and volume before forwarding to audio',
      () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FakeUserApiRunner()),
      PlaybackQueueController(),
    );

    await controller.setSpeed(9);
    await controller.setVolume(-1);

    expect(engine.speed, 2);
    expect(engine.volume, 0);
    expect(controller.state.speed, 2);
    expect(controller.state.volume, 0);
  });

  test('skips a track whose URL cannot be resolved', () async {
    final engine = _FakeAudioEngine();
    final queue = PlaybackQueueController()
      ..replaceQueue(const [track, secondTrack]);
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FailingTrackRunner({track.id})),
      queue,
    );

    await controller.playTrack(track);
    await Future<void>.delayed(Duration.zero);

    expect(queue.state.currentTrack?.id, secondTrack.id);
    expect(controller.state.track?.id, secondTrack.id);
    expect(controller.state.isPlaying, isTrue);
  });

  test('keeps an error when every queued track fails', () async {
    final engine = _FakeAudioEngine();
    final queue = PlaybackQueueController()..replaceQueue(const [track]);
    final controller = PlayerController(
      engine,
      PlaybackResolver(_FailingTrackRunner({track.id})),
      queue,
    );

    await controller.playTrack(track);

    expect(controller.state.status, AudioEngineStatus.error);
    expect(controller.state.error?.message, '测试取链失败');
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
  double? speed;
  double? volume;
  var stopCount = 0;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<AudioEngineCommand> get commands => _commands.stream;

  @override
  Future<void> load(Track track, Uri uri,
      {Map<String, String> headers = const {}}) async {
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
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> stop() async => stopCount++;

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
  Future<ResolvedPlaybackUrl> resolveMusicUrl(
    Track track,
    AudioQuality quality,
  ) async {
    resolveCount++;
    return ResolvedPlaybackUrl(
        Uri.parse('https://example.com/$resolveCount.mp3'));
  }
}

final class _DeferredUserApiRunner implements UserApiRunner {
  final _responses = <String, Completer<ResolvedPlaybackUrl>>{};

  @override
  Future<void> clear() async {}

  void complete(Track track, Uri uri) =>
      (_responses[track.id] ??= Completer<ResolvedPlaybackUrl>())
          .complete(ResolvedPlaybackUrl(uri));

  @override
  Future<UserApiManifest> load(String script) async =>
      const UserApiManifest({'kw'});

  @override
  Future<ResolvedPlaybackUrl> resolveMusicUrl(
    Track track,
    AudioQuality quality,
  ) =>
      (_responses[track.id] ??= Completer<ResolvedPlaybackUrl>()).future;
}

final class _FailingTrackRunner implements UserApiRunner {
  _FailingTrackRunner(this._failedIds);

  final Set<String> _failedIds;

  @override
  Future<void> clear() async {}

  @override
  Future<UserApiManifest> load(String script) async =>
      const UserApiManifest({'kw'});

  @override
  Future<ResolvedPlaybackUrl> resolveMusicUrl(
    Track track,
    AudioQuality quality,
  ) async {
    if (_failedIds.contains(track.id)) {
      throw const AppFailure(
        code: AppFailureCode.noNetwork,
        message: '测试取链失败',
      );
    }
    return ResolvedPlaybackUrl(
      Uri.parse('https://example.com/${track.sourceTrackId}.mp3'),
    );
  }
}

final class _QualityFallbackRunner implements UserApiRunner {
  final qualities = <AudioQuality>[];

  @override
  Future<void> clear() async {}

  @override
  Future<UserApiManifest> load(String script) async =>
      const UserApiManifest({'kw'});

  @override
  Future<ResolvedPlaybackUrl> resolveMusicUrl(
    Track track,
    AudioQuality quality,
  ) async {
    qualities.add(quality);
    if (quality == AudioQuality.flac) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'FLAC 暂不可用',
      );
    }
    return ResolvedPlaybackUrl(
      Uri.parse('https://example.com/${quality.name}.mp3'),
    );
  }
}

final class _ActualQualityRunner implements UserApiRunner {
  @override
  Future<void> clear() async {}

  @override
  Future<UserApiManifest> load(String script) async =>
      const UserApiManifest({'kw'});

  @override
  Future<ResolvedPlaybackUrl> resolveMusicUrl(
    Track track,
    AudioQuality quality,
  ) async =>
      ResolvedPlaybackUrl(
        Uri.parse('https://example.com/actual-quality.mp3'),
        quality: AudioQuality.high320k,
      );
}
