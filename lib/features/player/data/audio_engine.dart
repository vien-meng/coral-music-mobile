import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../../domain/music.dart';

enum AudioEngineStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  completed,
  error
}

final class AudioEngineSnapshot {
  const AudioEngineSnapshot({
    this.track,
    this.position = Duration.zero,
    this.duration,
    this.status = AudioEngineStatus.idle,
    this.error,
  });

  final Track? track;
  final Duration position;
  final Duration? duration;
  final AudioEngineStatus status;
  final String? error;

  bool get isPlaying => status == AudioEngineStatus.playing;
}

abstract interface class AudioEngine {
  Stream<AudioEngineSnapshot> get snapshots;

  Future<void> load(Track track, Uri uri);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}

final class JustAudioEngine implements AudioEngine {
  JustAudioEngine() {
    _subscriptions.add(_player.playerStateStream.listen((state) {
      _emit(
        status: switch (state.processingState) {
          ProcessingState.idle => AudioEngineStatus.idle,
          ProcessingState.loading ||
          ProcessingState.buffering =>
            AudioEngineStatus.loading,
          ProcessingState.ready => state.playing
              ? AudioEngineStatus.playing
              : AudioEngineStatus.paused,
          ProcessingState.completed => AudioEngineStatus.completed,
        },
      );
    }));
    _subscriptions.add(
        _player.positionStream.listen((position) => _emit(position: position)));
    _subscriptions.add(
        _player.durationStream.listen((duration) => _emit(duration: duration)));
    _subscriptions.add(_player.errorStream.listen((_) {
      _emit(status: AudioEngineStatus.error, error: '音频播放失败');
    }));
  }

  final AudioPlayer _player = AudioPlayer();
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  AudioEngineSnapshot _snapshot = const AudioEngineSnapshot();

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(Track track, Uri uri) async {
    _snapshot =
        AudioEngineSnapshot(track: track, status: AudioEngineStatus.loading);
    _snapshots.add(_snapshot);
    await _player.setUrl(uri.toString());
    _emit(track: track, status: AudioEngineStatus.ready, error: null);
  }

  @override
  Future<void> play() {
    _emit(status: AudioEngineStatus.playing, error: null);
    unawaited(_player.play().catchError((_) {
      _emit(status: AudioEngineStatus.error, error: '音频播放失败');
    }));
    return Future.value();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _emit(status: AudioEngineStatus.paused);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _snapshots.close();
  }

  void _emit({
    Track? track,
    Duration? position,
    Duration? duration,
    AudioEngineStatus? status,
    String? error,
  }) {
    _snapshot = AudioEngineSnapshot(
      track: track ?? _snapshot.track,
      position: position ?? _snapshot.position,
      duration: duration ?? _snapshot.duration,
      status: status ?? _snapshot.status,
      error: error,
    );
    _snapshots.add(_snapshot);
  }
}
