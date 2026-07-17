import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
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

enum AudioEngineCommand { next, previous }

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
  Stream<AudioEngineCommand> get commands;

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
  Future<_CoralAudioHandler>? _handler;
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  final _commands = StreamController<AudioEngineCommand>.broadcast();
  StreamSubscription<AudioEngineSnapshot>? _snapshotSubscription;
  StreamSubscription<AudioEngineCommand>? _commandSubscription;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<AudioEngineCommand> get commands => _commands.stream;

  @override
  Future<void> load(Track track, Uri uri) async {
    await (await _getHandler()).load(track, uri);
  }

  @override
  Future<void> play() async => (await _getHandler()).play();

  @override
  Future<void> pause() async => (await _getHandler()).pause();

  @override
  Future<void> seek(Duration position) async =>
      (await _getHandler()).seek(position);

  @override
  Future<void> setSpeed(double speed) async =>
      (await _getHandler()).setSpeed(speed);

  @override
  Future<void> setVolume(double volume) async =>
      (await _getHandler()).setVolume(volume);

  @override
  Future<void> stop() async => (await _getHandler()).stop();

  @override
  Future<void> dispose() async {
    final handler = _handler;
    _handler = null;
    await _snapshotSubscription?.cancel();
    await _commandSubscription?.cancel();
    try {
      if (handler != null) await (await handler).dispose();
    } finally {
      await _setBackgroundMediaEnabled(false);
      await _snapshots.close();
      await _commands.close();
    }
  }

  Future<_CoralAudioHandler> _getHandler() async {
    final future = _handler ??= _createHandler();
    try {
      final handler = await future;
      _snapshotSubscription ??= handler.snapshots.listen(
        _snapshots.add,
        onError: (_, __) => _snapshots.add(const AudioEngineSnapshot(
          status: AudioEngineStatus.error,
          error: '音频播放失败',
        )),
      );
      _commandSubscription ??= handler.commands.listen(_commands.add);
      return handler;
    } on Object {
      if (identical(_handler, future)) _handler = null;
      rethrow;
    }
  }
}

Future<_CoralAudioHandler> _createHandler() async {
  var backgroundMediaEnabled = false;
  try {
    await _setBackgroundMediaEnabled(true);
    backgroundMediaEnabled = true;
    final handler = await AudioService.init(
      builder: _CoralAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.coral.music.mobile.playback',
        androidNotificationChannelName: '珊瑚音乐播放',
      ),
    );
    await (await AudioSession.instance)
        .configure(AudioSessionConfiguration.music());
    return handler;
  } on MissingPluginException {
    if (backgroundMediaEnabled) await _setBackgroundMediaEnabled(false);
    // ponytail: Harmony falls back to its just_audio implementation until audio_service gains an OHOS backend.
    return _CoralAudioHandler();
  } on Object {
    if (backgroundMediaEnabled) await _setBackgroundMediaEnabled(false);
    rethrow;
  }
}

const _backgroundMediaChannel = MethodChannel('coral_music/background_media');

Future<void> _setBackgroundMediaEnabled(bool enabled) async {
  try {
    await _backgroundMediaChannel.invokeMethod<void>(
      'setBackgroundMediaEnabled',
      {'enabled': enabled},
    );
  } on MissingPluginException {
    // ponytail: only Android needs a manifest receiver; other platforms own their media route.
  }
}

final class _CoralAudioHandler extends BaseAudioHandler with SeekHandler {
  _CoralAudioHandler() {
    _subscriptions.add(_player.playerStateStream.listen((value) {
      _emit(status: _statusOf(value));
    }));
    _subscriptions
        .add(_player.positionStream.listen((value) => _emit(position: value)));
    _subscriptions
        .add(_player.durationStream.listen((value) => _emit(duration: value)));
    _subscriptions.add(_player.errorStream.listen(
        (_) => _emit(status: AudioEngineStatus.error, error: '音频播放失败')));
  }

  final _player = AudioPlayer();
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  final _commands = StreamController<AudioEngineCommand>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  AudioEngineSnapshot _snapshot = const AudioEngineSnapshot();

  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;
  Stream<AudioEngineCommand> get commands => _commands.stream;

  Future<void> load(Track track, Uri uri) async {
    _snapshot =
        AudioEngineSnapshot(track: track, status: AudioEngineStatus.loading);
    _snapshots.add(_snapshot);
    mediaItem.add(MediaItem(
      id: uri.toString(),
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      artUri: track.coverUri,
    ));
    await _player.setUrl(uri.toString());
    _emit(track: track, status: AudioEngineStatus.ready, error: null);
  }

  @override
  Future<void> play() async {
    _emit(status: AudioEngineStatus.playing, error: null);
    await _player.play();
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

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> skipToNext() async => _commands.add(AudioEngineCommand.next);

  @override
  Future<void> skipToPrevious() async =>
      _commands.add(AudioEngineCommand.previous);

  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(status: AudioEngineStatus.idle);
    await super.stop();
  }

  Future<void> dispose() async {
    try {
      await stop();
    } finally {
      await Future.wait(_subscriptions.map((item) => item.cancel()));
      await _player.dispose();
      await _snapshots.close();
      await _commands.close();
    }
  }

  void _emit(
      {Track? track,
      Duration? position,
      Duration? duration,
      AudioEngineStatus? status,
      String? error}) {
    _snapshot = AudioEngineSnapshot(
      track: track ?? _snapshot.track,
      position: position ?? _snapshot.position,
      duration: duration ?? _snapshot.duration,
      status: status ?? _snapshot.status,
      error: error,
    );
    _snapshots.add(_snapshot);
    playbackState.add(PlaybackState(
      controls: _snapshot.status == AudioEngineStatus.playing
          ? const [
              MediaControl.skipToPrevious,
              MediaControl.pause,
              MediaControl.skipToNext,
            ]
          : const [
              MediaControl.skipToPrevious,
              MediaControl.play,
              MediaControl.skipToNext,
            ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_snapshot.status) {
        AudioEngineStatus.idle => AudioProcessingState.idle,
        AudioEngineStatus.loading => AudioProcessingState.loading,
        AudioEngineStatus.completed => AudioProcessingState.completed,
        AudioEngineStatus.error => AudioProcessingState.error,
        _ => AudioProcessingState.ready,
      },
      playing: _snapshot.status == AudioEngineStatus.playing,
      updatePosition: _snapshot.position,
      speed: _player.speed,
    ));
  }

  AudioEngineStatus _statusOf(PlayerState state) =>
      switch (state.processingState) {
        ProcessingState.idle => AudioEngineStatus.idle,
        ProcessingState.loading ||
        ProcessingState.buffering =>
          AudioEngineStatus.loading,
        ProcessingState.ready =>
          state.playing ? AudioEngineStatus.playing : AudioEngineStatus.paused,
        ProcessingState.completed => AudioEngineStatus.completed,
      };
}
