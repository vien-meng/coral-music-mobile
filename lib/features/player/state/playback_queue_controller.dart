import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';

final playbackQueueProvider =
    StateNotifierProvider<PlaybackQueueController, PlaybackQueueState>(
  (ref) => PlaybackQueueController(),
);

final class PlaybackQueueState {
  const PlaybackQueueState({
    this.tracks = const [],
    this.currentIndex = -1,
    this.contextId,
    this.mode = PlaybackMode.listLoop,
  });

  final List<Track> tracks;
  final int currentIndex;
  final String? contextId;
  final PlaybackMode mode;

  Track? get currentTrack => currentIndex < 0 || currentIndex >= tracks.length
      ? null
      : tracks[currentIndex];
}

final class PlaybackQueueController extends StateNotifier<PlaybackQueueState> {
  PlaybackQueueController({Random? random})
      : _random = random ?? Random(),
        super(const PlaybackQueueState());

  final Random _random;
  final _shuffleHistory = <int>{};

  void replaceQueue(
    List<Track> tracks, {
    int startIndex = 0,
    String? contextId,
  }) {
    if (tracks.isEmpty) {
      _shuffleHistory.clear();
      state = const PlaybackQueueState();
      return;
    }
    if (startIndex < 0 || startIndex >= tracks.length) {
      throw RangeError.index(startIndex, tracks, 'startIndex');
    }
    state = PlaybackQueueState(
      tracks: List.unmodifiable(tracks),
      currentIndex: startIndex,
      contextId: contextId,
    );
    _shuffleHistory
      ..clear()
      ..add(startIndex);
  }

  void select(int index) {
    if (index < 0 || index >= state.tracks.length) {
      throw RangeError.index(index, state.tracks, 'index');
    }
    _setIndex(index);
  }

  Track? selectNext() => _selectOffset(1);

  Track? selectPrevious() => _selectOffset(-1);

  void setMode(PlaybackMode mode) {
    if (state.mode == mode) return;
    state = PlaybackQueueState(
      tracks: state.tracks,
      currentIndex: state.currentIndex,
      contextId: state.contextId,
      mode: mode,
    );
    _shuffleHistory
      ..clear()
      ..addAll(state.currentIndex < 0 ? const [] : [state.currentIndex]);
  }

  void cycleMode() {
    final nextIndex = (state.mode.index + 1) % PlaybackMode.values.length;
    setMode(PlaybackMode.values[nextIndex]);
  }

  Track? selectAfterCompletion() => switch (state.mode) {
        PlaybackMode.listLoop => selectNext(),
        PlaybackMode.singleLoop => state.currentTrack,
        PlaybackMode.shuffle => _selectShuffle(),
      };

  Track? selectAfterFailure() =>
      state.mode == PlaybackMode.shuffle ? _selectShuffle() : selectNext();

  Track? _selectOffset(int offset) {
    if (state.tracks.isEmpty) return null;
    final currentIndex = state.currentIndex < 0 ? 0 : state.currentIndex;
    final index =
        (currentIndex + offset + state.tracks.length) % state.tracks.length;
    select(index);
    return state.currentTrack;
  }

  Track? _selectShuffle() {
    if (state.tracks.isEmpty) return null;
    if (state.tracks.length == 1) return state.currentTrack;
    final currentIndex = state.currentIndex < 0 ? 0 : state.currentIndex;
    var candidates = List<int>.generate(state.tracks.length, (index) => index)
        .where((index) =>
            index != currentIndex && !_shuffleHistory.contains(index))
        .toList();
    if (candidates.isEmpty) {
      _shuffleHistory
        ..clear()
        ..add(currentIndex);
      candidates = List<int>.generate(state.tracks.length, (index) => index)
          .where((index) => index != currentIndex)
          .toList();
    }
    select(candidates[_random.nextInt(candidates.length)]);
    return state.currentTrack;
  }

  void _setIndex(int index) {
    state = PlaybackQueueState(
      tracks: state.tracks,
      currentIndex: index,
      contextId: state.contextId,
      mode: state.mode,
    );
    if (state.mode == PlaybackMode.shuffle) _shuffleHistory.add(index);
  }
}
