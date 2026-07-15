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
  });

  final List<Track> tracks;
  final int currentIndex;
  final String? contextId;

  Track? get currentTrack => currentIndex < 0 || currentIndex >= tracks.length
      ? null
      : tracks[currentIndex];
}

final class PlaybackQueueController extends StateNotifier<PlaybackQueueState> {
  PlaybackQueueController() : super(const PlaybackQueueState());

  void replaceQueue(
    List<Track> tracks, {
    int startIndex = 0,
    String? contextId,
  }) {
    if (tracks.isEmpty) {
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
  }

  void select(int index) {
    if (index < 0 || index >= state.tracks.length) {
      throw RangeError.index(index, state.tracks, 'index');
    }
    state = PlaybackQueueState(
      tracks: state.tracks,
      currentIndex: index,
      contextId: state.contextId,
    );
  }
}
