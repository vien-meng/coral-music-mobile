import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../data/library_store.dart';

final libraryProvider = StateNotifierProvider<LibraryController, LibraryState>(
  (ref) => LibraryController(ref.watch(libraryStoreProvider)),
);

final class LibraryState {
  const LibraryState({
    this.playlists = const [],
    this.selectedPlaylist,
    this.tracks = const [],
    this.isLoading = false,
    this.error,
  });

  final List<UserPlaylist> playlists;
  final UserPlaylist? selectedPlaylist;
  final List<Track> tracks;
  final bool isLoading;
  final AppFailure? error;

  LibraryState copyWith({
    List<UserPlaylist>? playlists,
    UserPlaylist? selectedPlaylist,
    List<Track>? tracks,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
    bool clearSelectedPlaylist = false,
  }) =>
      LibraryState(
        playlists: playlists ?? this.playlists,
        selectedPlaylist: clearSelectedPlaylist
            ? null
            : selectedPlaylist ?? this.selectedPlaylist,
        tracks: clearSelectedPlaylist ? const [] : tracks ?? this.tracks,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final class LibraryController extends StateNotifier<LibraryState> {
  LibraryController(this._store) : super(const LibraryState());

  final LibraryStore _store;

  Future<void> load() => _run(() async {
        state = state.copyWith(
          playlists: await _store.listPlaylists(),
          isLoading: false,
          clearError: true,
        );
      });

  Future<void> create(String name) => _run(() async {
        await _store.createPlaylist(name);
        state = state.copyWith(
          playlists: await _store.listPlaylists(),
          isLoading: false,
          clearError: true,
        );
      });

  Future<void> rename(UserPlaylist playlist, String name) => _run(() async {
        await _store.renamePlaylist(playlist, name);
        state = state.copyWith(
          playlists: await _store.listPlaylists(),
          isLoading: false,
          clearError: true,
        );
      });

  Future<void> delete(String id) => _run(() async {
        await _store.deletePlaylist(id);
        state = state.copyWith(
          playlists: await _store.listPlaylists(),
          isLoading: false,
          clearError: true,
        );
      });

  Future<void> open(UserPlaylist playlist) => _run(() async {
        state = state.copyWith(
          selectedPlaylist: playlist,
          tracks: await _store.listTracks(playlist.id),
          isLoading: false,
          clearError: true,
        );
      });

  Future<void> openFavorites() => _run(() async {
        state = state.copyWith(
          selectedPlaylist: UserPlaylist(
            id: LibraryStore.favoritesId,
            name: '我的收藏',
            position: -1,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          tracks: await _store.listFavorites(),
          isLoading: false,
          clearError: true,
        );
      });

  void close() => state = state.copyWith(clearSelectedPlaylist: true);

  Future<bool> addTrack(UserPlaylist playlist, Track track) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final added = await _store.addTrack(playlist.id, track);
      state = state.copyWith(
        tracks: state.selectedPlaylist?.id == playlist.id
            ? await _store.listTracks(playlist.id)
            : null,
        isLoading: false,
        clearError: true,
      );
      return added;
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '歌曲加入列表失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
      return false;
    }
  }

  Future<bool> isFavorite(String trackId) => _store.isFavorite(trackId);

  Future<bool> toggleFavorite(Track track) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final favorite = await _store.toggleFavorite(track);
      state = state.copyWith(
        tracks: state.selectedPlaylist?.id == LibraryStore.favoritesId
            ? await _store.listFavorites()
            : null,
        isLoading: false,
        clearError: true,
      );
      return favorite;
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '收藏歌曲失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> removeTrack(String trackId) => _run(() async {
        final playlist = state.selectedPlaylist;
        if (playlist == null) return;
        await _store.removeTrack(playlist.id, trackId);
        state = state.copyWith(
          tracks: await _store.listTracks(playlist.id),
          isLoading: false,
          clearError: true,
        );
      });

  Future<void> removeTracks(Iterable<String> trackIds) => _run(() async {
        final playlist = state.selectedPlaylist;
        if (playlist == null) return;
        await _store.removeTracks(playlist.id, trackIds);
        state = state.copyWith(
          tracks: await _store.listTracks(playlist.id),
          isLoading: false,
          clearError: true,
        );
      });

  Future<void> reorderTracks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    if (oldIndex == newIndex) return Future.value();
    final tracks = [...state.tracks];
    final moved = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, moved);
    return _run(() async {
      final playlist = state.selectedPlaylist;
      if (playlist == null) return;
      await _store.saveTrackOrder(
        playlist.id,
        tracks.map((track) => track.id).toList(growable: false),
      );
      state = state.copyWith(
        tracks: await _store.listTracks(playlist.id),
        isLoading: false,
        clearError: true,
      );
    });
  }

  Future<int> transferTracks(String targetPlaylistId, Iterable<String> ids,
      {required bool move}) async {
    if (state.isLoading) return 0;
    final playlist = state.selectedPlaylist;
    if (playlist == null) return 0;
    final selected = ids.toSet();
    final tracks = state.tracks
        .where((track) => selected.contains(track.id))
        .toList(growable: false);
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final added = await _store.transferTracks(
        fromPlaylistId: playlist.id,
        toPlaylistId: targetPlaylistId,
        tracks: tracks,
        move: move,
      );
      state = state.copyWith(
        tracks: move ? await _store.listTracks(playlist.id) : null,
        isLoading: false,
        clearError: true,
      );
      return added;
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: move ? '移动歌曲失败' : '复制歌曲失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
      return 0;
    }
  }

  Future<void> pinTracks(Iterable<String> ids) {
    final playlist = state.selectedPlaylist;
    if (playlist == null) return Future.value();
    final selected = ids.toSet();
    final tracks = [
      ...state.tracks.where((track) => selected.contains(track.id)),
      ...state.tracks.where((track) => !selected.contains(track.id)),
    ];
    return _run(() async {
      await _store.saveTrackOrder(
        playlist.id,
        tracks.map((track) => track.id).toList(growable: false),
      );
      state = state.copyWith(
        tracks: await _store.listTracks(playlist.id),
        isLoading: false,
        clearError: true,
      );
    });
  }

  Future<void> reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    if (oldIndex == newIndex) return Future.value();
    final playlists = [...state.playlists];
    final moved = playlists.removeAt(oldIndex);
    playlists.insert(newIndex, moved);
    return _run(() async {
      await _store.saveOrder(playlists.map((playlist) => playlist.id).toList());
      state = state.copyWith(
        playlists: await _store.listPlaylists(),
        isLoading: false,
        clearError: true,
      );
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await operation();
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '列表数据保存失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }
}
