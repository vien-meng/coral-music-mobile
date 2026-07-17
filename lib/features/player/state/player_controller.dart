import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../../library/data/library_store.dart';
import '../data/audio_engine.dart';
import '../data/audio_file_probe.dart';
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

final audioFileProbeProvider =
    Provider<AudioFileProbe>((_) => HttpAudioFileProbe());

final playerProvider = StateNotifierProvider<PlayerController, PlayerState>(
  (ref) => PlayerController(
    ref.watch(audioEngineProvider),
    ref.watch(playbackResolverProvider),
    ref.watch(playbackQueueProvider.notifier),
    ref.watch(libraryStoreProvider),
    ref.watch(audioFileProbeProvider),
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
    this.quality = AudioQuality.flac,
    this.fileInfo,
    this.error,
  });

  final Track? track;
  final Duration position;
  final Duration? duration;
  final AudioEngineStatus status;
  final double speed;
  final double volume;
  final AudioQuality quality;
  final AudioFileInfo? fileInfo;
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
    AudioFileInfo? fileInfo,
    AppFailure? error,
    bool clearError = false,
    bool clearFileInfo = false,
  }) =>
      PlayerState(
        track: track ?? this.track,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        status: status ?? this.status,
        speed: speed ?? this.speed,
        volume: volume ?? this.volume,
        quality: quality ?? this.quality,
        fileInfo: clearFileInfo ? null : fileInfo ?? this.fileInfo,
        error: clearError ? null : error ?? this.error,
      );
}

final class PlayerController extends StateNotifier<PlayerState> {
  PlayerController(
    this._engine,
    this._resolver,
    this._queue, [
    LibraryStore? library,
    AudioFileProbe? fileProbe,
    Future<List<PlayHistoryEntry>> Function()? loadHistory,
  ])  : _library = library ?? LibraryStore(),
        _fileProbe = fileProbe ?? const NoopAudioFileProbe(),
        super(const PlayerState()) {
    _loadHistory = loadHistory ?? _library.listHistory;
    _subscription = _engine.snapshots.listen(_onSnapshot);
    _engineCommandSubscription = _engine.commands.listen(_onEngineCommand);
  }

  final AudioEngine _engine;
  final PlaybackResolver _resolver;
  final PlaybackQueueController _queue;
  final LibraryStore _library;
  final AudioFileProbe _fileProbe;
  late final Future<List<PlayHistoryEntry>> Function() _loadHistory;
  final _failedTrackIds = <String>{};
  final _refreshedTrackQualities = <String>{};
  final _handledEngineFailures = <String>{};
  var _playRequest = 0;
  String? _recordedHistoryTrackId;
  String? _lastPersistedTrackId;
  Duration _lastPersistedPosition = Duration.zero;
  Future<void> _historyWrites = Future.value();
  late final StreamSubscription<AudioEngineSnapshot> _subscription;
  late final StreamSubscription<AudioEngineCommand> _engineCommandSubscription;

  static const _positionCheckpoint = Duration(seconds: 15);

  Future<void> toggle(Track track) async {
    if (state.track?.id == track.id && state.isPlaying) return pause();
    if (state.track?.id == track.id &&
        (state.status == AudioEngineStatus.ready ||
            state.status == AudioEngineStatus.paused)) {
      return _engine.play();
    }
    return playTrack(
      track,
      initialPosition: state.track?.id == track.id ? state.position : null,
    );
  }

  Future<void> retryCurrent() {
    final track = state.track;
    if (track == null) return Future.value();
    return playTrack(
      track,
      refreshUrl: true,
      initialPosition: state.position,
    );
  }

  Future<void> restoreLastPlayback() async {
    if (state.track != null) return;
    try {
      final history = await _loadHistory();
      if (state.track != null || history.isEmpty) return;
      final latest = history.first;
      state = PlayerState(
        track: latest.track,
        position: _validResumePosition(latest.track, latest.lastPosition) ??
            Duration.zero,
        speed: state.speed,
        volume: state.volume,
        quality: _defaultQuality(latest.track),
      );
    } on Object {
      // ponytail: history is optional startup context; a storage failure must not block the app shell.
    }
  }

  Future<void> playTrack(
    Track track, {
    AudioQuality? quality,
    bool retryFailed = true,
    bool refreshUrl = false,
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    final request = ++_playRequest;
    if (state.track?.id != track.id &&
        state.status != AudioEngineStatus.idle &&
        state.status != AudioEngineStatus.loading) {
      await _engine.stop();
      if (request != _playRequest) return;
    }
    if (retryFailed) {
      _failedTrackIds.remove(track.id);
      _refreshedTrackQualities
          .removeWhere((key) => key.startsWith('${track.id}:'));
      _handledEngineFailures
          .removeWhere((key) => key.startsWith('${track.id}:'));
    }
    final resolvedQuality = quality ?? _defaultQuality(track);
    if (refreshUrl) {
      _handledEngineFailures.remove(_engineFailureKey(track, resolvedQuality));
    }
    state = PlayerState(
      track: track,
      status: AudioEngineStatus.loading,
      speed: state.speed,
      volume: state.volume,
      quality: resolvedQuality,
      fileInfo: null,
    );
    ResolvedPlaybackUrl playbackUrl;
    try {
      playbackUrl = await _resolver.resolve(
        track,
        quality: resolvedQuality,
        forceRefresh: refreshUrl,
      );
    } on AppFailure catch (error) {
      if (request != _playRequest) return;
      _handleResolveFailure(
        track,
        resolvedQuality,
        error,
        initialPosition: initialPosition,
        autoPlay: autoPlay,
      );
      return;
    } on Object catch (error) {
      if (request != _playRequest) return;
      _handleResolveFailure(
        track,
        resolvedQuality,
        AppFailure(
          code: AppFailureCode.unknown,
          message: '播放地址解析失败',
          diagnostic: error.runtimeType.toString(),
        ),
        initialPosition: initialPosition,
        autoPlay: autoPlay,
      );
      return;
    }
    if (request != _playRequest) return;
    final actualQuality = playbackUrl.quality ?? resolvedQuality;
    state = state.copyWith(quality: actualQuality);
    unawaited(_probeFileInfo(request, playbackUrl.uri));
    try {
      await _engine.load(track, playbackUrl.uri);
      if (request != _playRequest) return;
      final resumePosition = _validResumePosition(track, initialPosition);
      if (resumePosition != null) await _engine.seek(resumePosition);
      if (request != _playRequest) return;
      if (autoPlay) await _engine.play();
    } on AppFailure catch (error) {
      if (request != _playRequest) return;
      _handleEngineFailure(
        track,
        actualQuality,
        error,
        initialPosition: initialPosition,
        autoPlay: autoPlay,
      );
    } on Object catch (error) {
      if (request != _playRequest) return;
      _handleEngineFailure(
        track,
        actualQuality,
        AppFailure(
          code: AppFailureCode.unknown,
          message: '播放加载失败',
          diagnostic: error.runtimeType.toString(),
        ),
        initialPosition: initialPosition,
        autoPlay: autoPlay,
      );
    }
  }

  Future<void> playDebugUrl(String rawUrl) async {
    final request = ++_playRequest;
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
    state = PlayerState(
      track: track,
      status: AudioEngineStatus.loading,
      speed: state.speed,
      volume: state.volume,
      fileInfo: null,
    );
    try {
      await _engine.load(track, uri);
      if (request != _playRequest) return;
      await _engine.play();
    } on Object catch (error, stackTrace) {
      if (request != _playRequest) return;
      assert(() {
        debugPrint('调试音频加载失败：${error.runtimeType}');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
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

  Future<void> pause() async {
    await _engine.pause();
    final track = state.track;
    if (track != null) _persistPosition(track, state.position, force: true);
  }

  Future<void> seek(Duration position) async {
    await _engine.seek(position);
    final track = state.track;
    if (track == null) return;
    state = state.copyWith(position: position);
    _persistPosition(track, position, force: true);
  }

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
    return playTrack(
      track,
      quality: quality,
      initialPosition: state.position,
      autoPlay: state.isPlaying,
    );
  }

  void _onSnapshot(AudioEngineSnapshot snapshot) {
    if (state.track != null && snapshot.track?.id != state.track?.id) return;
    if (snapshot.status == AudioEngineStatus.error && snapshot.track != null) {
      _handleEngineFailure(
        snapshot.track!,
        state.quality,
        AppFailure(
            code: AppFailureCode.unknown, message: snapshot.error ?? '音频播放失败'),
        initialPosition: snapshot.position,
      );
      return;
    }
    if (snapshot.status == AudioEngineStatus.completed &&
        snapshot.track?.id == state.track?.id) {
      _persistPosition(snapshot.track!, Duration.zero, force: true);
      final nextTrack = _queue.selectAfterCompletion();
      if (nextTrack != null) {
        unawaited(playTrack(nextTrack));
        return;
      }
    }
    if (snapshot.status == AudioEngineStatus.playing &&
        snapshot.track != null &&
        _recordedHistoryTrackId != snapshot.track!.id) {
      _recordedHistoryTrackId = snapshot.track!.id;
      _recordHistory(snapshot.track!, snapshot.position);
    } else if (snapshot.track != null &&
        (snapshot.status == AudioEngineStatus.playing ||
            snapshot.status == AudioEngineStatus.paused)) {
      _persistPosition(
        snapshot.track!,
        snapshot.position,
        force: snapshot.status == AudioEngineStatus.paused,
      );
    }
    state = PlayerState(
      track: snapshot.track,
      position: snapshot.position,
      duration: snapshot.duration,
      status: snapshot.status,
      speed: state.speed,
      volume: state.volume,
      quality: state.quality,
      fileInfo: state.fileInfo,
      error: snapshot.error == null
          ? null
          : AppFailure(code: AppFailureCode.unknown, message: snapshot.error!),
    );
  }

  void _onEngineCommand(AudioEngineCommand command) {
    switch (command) {
      case AudioEngineCommand.next:
        final next = _queue.selectNext();
        if (next != null) unawaited(playTrack(next));
      case AudioEngineCommand.previous:
        final previous = _queue.selectPrevious();
        if (previous != null) unawaited(playTrack(previous));
    }
  }

  Future<void> _probeFileInfo(int request, Uri uri) async {
    final info = await _fileProbe.probe(uri);
    if (request != _playRequest) return;
    state = state.copyWith(fileInfo: info);
  }

  void _recordHistory(Track track, Duration position) => _queueHistoryWrite(
        () => _library.recordHistory(track, position),
      );

  void _persistPosition(Track track, Duration position, {bool force = false}) {
    final sameTrack = _lastPersistedTrackId == track.id;
    final difference = position - _lastPersistedPosition;
    if (!force && sameTrack && difference.abs() < _positionCheckpoint) return;
    _lastPersistedTrackId = track.id;
    _lastPersistedPosition = position;
    _updateHistoryPosition(track.id, position);
  }

  void _updateHistoryPosition(String trackId, Duration position) =>
      _queueHistoryWrite(
        () => _library.updateHistoryPosition(trackId, position),
      );

  void _queueHistoryWrite(Future<void> Function() write) {
    _historyWrites = _historyWrites
        .then((_) => write())
        .onError((Object error, StackTrace stackTrace) {
      // ponytail: history is non-critical; surface storage failures stay in Library UI.
    });
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

  void _handleEngineFailure(
    Track track,
    AudioQuality quality,
    AppFailure error, {
    Duration? initialPosition,
    bool autoPlay = true,
  }) {
    if (!_handledEngineFailures.add(_engineFailureKey(track, quality))) return;
    if (_refreshedTrackQualities.add('${track.id}:${quality.name}')) {
      _resolver.invalidate(track, quality: quality);
      unawaited(
        playTrack(
          track,
          quality: quality,
          retryFailed: false,
          refreshUrl: true,
          initialPosition: initialPosition,
          autoPlay: autoPlay,
        ),
      );
      return;
    }
    final fallback = _lowerQuality(track, quality);
    if (fallback != null) {
      unawaited(
        playTrack(
          track,
          quality: fallback,
          retryFailed: false,
          initialPosition: initialPosition,
          autoPlay: autoPlay,
        ),
      );
      return;
    }
    _handleFailure(track, error);
  }

  String _engineFailureKey(Track track, AudioQuality quality) =>
      '${track.id}:${quality.name}';

  void _handleResolveFailure(
    Track track,
    AudioQuality quality,
    AppFailure error, {
    Duration? initialPosition,
    bool autoPlay = true,
  }) {
    final fallback = _lowerQuality(track, quality);
    if (fallback != null) {
      unawaited(
        playTrack(
          track,
          quality: fallback,
          retryFailed: false,
          initialPosition: initialPosition,
          autoPlay: autoPlay,
        ),
      );
      return;
    }
    _handleFailure(track, error);
  }

  Track? _nextAvailableTrackAfterFailure() {
    for (var attempt = 0; attempt < _queue.state.tracks.length; attempt++) {
      final candidate = _queue.selectAfterFailure();
      if (candidate == null || _failedTrackIds.contains(candidate.id)) continue;
      return candidate;
    }
    return null;
  }

  AudioQuality _defaultQuality(Track track) =>
      defaultPlaybackQuality(track.availableQualities);

  AudioQuality? _lowerQuality(Track track, AudioQuality quality) {
    final candidates = track.availableQualities
        .where((item) => item.index > quality.index)
        .toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    return candidates.firstOrNull;
  }

  Duration? _validResumePosition(Track track, Duration? position) {
    if (position == null || position < const Duration(seconds: 5)) return null;
    final duration = track.duration;
    if (duration != null && position >= duration - const Duration(seconds: 3)) {
      return null;
    }
    return position;
  }

  @override
  void dispose() {
    _subscription.cancel();
    _engineCommandSubscription.cancel();
    super.dispose();
  }
}
