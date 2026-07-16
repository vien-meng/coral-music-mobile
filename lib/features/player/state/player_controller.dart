import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../data/audio_engine.dart';
import '../data/playback_resolver.dart';
import '../data/user_api_runner.dart';
import 'playback_queue_controller.dart';

final userApiRunnerProvider =
    Provider<UserApiRunner>((ref) => MethodChannelUserApiRunner());

final playbackResolverProvider = Provider<PlaybackResolver>(
  (ref) => PlaybackResolver(ref.watch(userApiRunnerProvider)),
);

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = JustAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final playerProvider = StateNotifierProvider<PlayerController, PlayerState>(
  (ref) => PlayerController(
    ref.watch(audioEngineProvider),
    ref.watch(playbackResolverProvider),
    ref.watch(playbackQueueProvider.notifier),
  ),
);

final class PlayerState {
  const PlayerState({
    this.track,
    this.position = Duration.zero,
    this.duration,
    this.status = AudioEngineStatus.idle,
    this.speed = 1,
    this.volume = 1,
    this.quality = AudioQuality.standard128k,
    this.error,
  });

  final Track? track;
  final Duration position;
  final Duration? duration;
  final AudioEngineStatus status;
  final double speed;
  final double volume;
  final AudioQuality quality;
  final AppFailure? error;

  bool get isPlaying => status == AudioEngineStatus.playing;

  PlayerState copyWith({
    Track? track,
    Duration? position,
    Duration? duration,
    AudioEngineStatus? status,
    double? speed,
    double? volume,
    AudioQuality? quality,
    AppFailure? error,
    bool clearError = false,
  }) =>
      PlayerState(
        track: track ?? this.track,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        status: status ?? this.status,
        speed: speed ?? this.speed,
        volume: volume ?? this.volume,
        quality: quality ?? this.quality,
        error: clearError ? null : error ?? this.error,
      );
}

final class PlayerController extends StateNotifier<PlayerState> {
  PlayerController(this._engine, this._resolver, this._queue)
      : super(const PlayerState()) {
    _subscription = _engine.snapshots.listen(_onSnapshot);
  }

  final AudioEngine _engine;
  final PlaybackResolver _resolver;
  final PlaybackQueueController _queue;
  final _failedTrackIds = <String>{};
  late final StreamSubscription<AudioEngineSnapshot> _subscription;

  Future<void> toggle(Track track) async {
    if (state.track?.id == track.id && state.isPlaying) return pause();
    if (state.track?.id == track.id &&
        (state.status == AudioEngineStatus.ready ||
            state.status == AudioEngineStatus.paused)) {
      return _engine.play();
    }
    return playTrack(track);
  }

  Future<void> playTrack(
    Track track, {
    AudioQuality? quality,
    bool retryFailed = true,
  }) async {
    if (retryFailed) _failedTrackIds.remove(track.id);
    final resolvedQuality = quality ?? _defaultQuality(track);
    state = PlayerState(
      track: track,
      status: AudioEngineStatus.loading,
      quality: resolvedQuality,
    );
    try {
      final uri = await _resolver.resolve(track, quality: resolvedQuality);
      await _engine.load(track, uri);
      await _engine.play();
    } on AppFailure catch (error) {
      _handleFailure(track, error);
    } on Object catch (error) {
      _handleFailure(
        track,
        AppFailure(
          code: AppFailureCode.unknown,
          message: '播放加载失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> playDebugUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.scheme != 'https') {
      state = state.copyWith(
        status: AudioEngineStatus.error,
        error: const AppFailure(
          code: AppFailureCode.invalidData,
          message: '调试音频地址必须使用 HTTPS',
        ),
      );
      return;
    }
    final track = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'debug',
      sourceTrackId: uri.toString(),
      title: '调试音频',
      artist: uri.host,
    );
    state = PlayerState(track: track, status: AudioEngineStatus.loading);
    try {
      await _engine.load(track, uri);
      await _engine.play();
    } on Object catch (error) {
      state = state.copyWith(
        status: AudioEngineStatus.error,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '调试音频加载失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> pause() => _engine.pause();

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> setSpeed(double speed) async {
    final normalized = speed.clamp(.5, 2.0).toDouble();
    await _engine.setSpeed(normalized);
    state = state.copyWith(speed: normalized);
  }

  Future<void> setVolume(double volume) async {
    final normalized = volume.clamp(0, 1).toDouble();
    await _engine.setVolume(normalized);
    state = state.copyWith(volume: normalized);
  }

  Future<void> setQuality(AudioQuality quality) {
    final track = state.track;
    if (track == null || !track.availableQualities.contains(quality)) {
      return Future.value();
    }
    return playTrack(track, quality: quality);
  }

  void _onSnapshot(AudioEngineSnapshot snapshot) {
    if (state.track != null && snapshot.track?.id != state.track?.id) return;
    if (snapshot.status == AudioEngineStatus.error && snapshot.track != null) {
      _handleFailure(
        snapshot.track!,
        AppFailure(
            code: AppFailureCode.unknown, message: snapshot.error ?? '音频播放失败'),
      );
      return;
    }
    if (snapshot.status == AudioEngineStatus.completed &&
        snapshot.track?.id == state.track?.id) {
      final nextTrack = _queue.selectAfterCompletion();
      if (nextTrack != null) {
        unawaited(playTrack(nextTrack));
        return;
      }
    }
    state = PlayerState(
      track: snapshot.track,
      position: snapshot.position,
      duration: snapshot.duration,
      status: snapshot.status,
      speed: state.speed,
      volume: state.volume,
      quality: state.quality,
      error: snapshot.error == null
          ? null
          : AppFailure(code: AppFailureCode.unknown, message: snapshot.error!),
    );
  }

  void _handleFailure(Track track, AppFailure error) {
    _failedTrackIds.add(track.id);
    final nextTrack = _nextAvailableTrackAfterFailure();
    if (nextTrack != null) {
      unawaited(playTrack(nextTrack, retryFailed: false));
      return;
    }
    state = state.copyWith(status: AudioEngineStatus.error, error: error);
  }

  Track? _nextAvailableTrackAfterFailure() {
    for (var attempt = 0; attempt < _queue.state.tracks.length; attempt++) {
      final candidate = _queue.selectAfterFailure();
      if (candidate == null || _failedTrackIds.contains(candidate.id)) continue;
      return candidate;
    }
    return null;
  }

  AudioQuality _defaultQuality(Track track) => track.availableQualities.isEmpty
      ? AudioQuality.standard128k
      : track.availableQualities.last;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
