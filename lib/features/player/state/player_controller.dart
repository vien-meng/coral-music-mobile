import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../data/audio_engine.dart';
import '../data/playback_resolver.dart';
import '../data/user_api_runner.dart';

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
  ),
);

final class PlayerState {
  const PlayerState({
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
  final AppFailure? error;

  bool get isPlaying => status == AudioEngineStatus.playing;

  PlayerState copyWith({
    Track? track,
    Duration? position,
    Duration? duration,
    AudioEngineStatus? status,
    AppFailure? error,
    bool clearError = false,
  }) =>
      PlayerState(
        track: track ?? this.track,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        status: status ?? this.status,
        error: clearError ? null : error ?? this.error,
      );
}

final class PlayerController extends StateNotifier<PlayerState> {
  PlayerController(this._engine, this._resolver) : super(const PlayerState()) {
    _subscription = _engine.snapshots.listen(_onSnapshot);
  }

  final AudioEngine _engine;
  final PlaybackResolver _resolver;
  late final StreamSubscription<AudioEngineSnapshot> _subscription;

  Future<void> toggle(Track track) async {
    if (state.track?.id == track.id && state.isPlaying) return pause();
    if (state.track?.id == track.id &&
        state.status == AudioEngineStatus.ready) {
      return _engine.play();
    }
    return playTrack(track);
  }

  Future<void> playTrack(Track track) async {
    state = PlayerState(track: track, status: AudioEngineStatus.loading);
    try {
      final uri = await _resolver.resolve(track);
      await _engine.load(track, uri);
      await _engine.play();
    } on AppFailure catch (error) {
      state = state.copyWith(status: AudioEngineStatus.error, error: error);
    } on Object catch (error) {
      state = state.copyWith(
        status: AudioEngineStatus.error,
        error: AppFailure(
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

  void _onSnapshot(AudioEngineSnapshot snapshot) {
    state = PlayerState(
      track: snapshot.track,
      position: snapshot.position,
      duration: snapshot.duration,
      status: snapshot.status,
      error: snapshot.error == null
          ? null
          : AppFailure(code: AppFailureCode.unknown, message: snapshot.error!),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
