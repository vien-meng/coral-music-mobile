import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import '../data/kuwo_playlist_service.dart';

final kuwoPlaylistServiceProvider = Provider<KuwoPlaylistService>(
  (ref) => KuwoPlaylistService(createHttpClient()),
);

final songListProvider =
    StateNotifierProvider<SongListController, SongListState>(
  (ref) => SongListController(ref.watch(kuwoPlaylistServiceProvider)),
);

final class SongListState {
  const SongListState({
    this.playlists = const [],
    this.detail,
    this.page = 1,
    this.pageSize = 30,
    this.total = 0,
    this.isLoading = false,
    this.error,
  });

  final List<OnlinePlaylist> playlists;
  final PlaylistDetail? detail;
  final int page;
  final int pageSize;
  final int total;
  final bool isLoading;
  final AppFailure? error;

  bool get hasNext => page * pageSize < total;

  SongListState copyWith({
    List<OnlinePlaylist>? playlists,
    PlaylistDetail? detail,
    int? page,
    int? pageSize,
    int? total,
    bool? isLoading,
    AppFailure? error,
    bool clearDetail = false,
    bool clearError = false,
  }) =>
      SongListState(
        playlists: playlists ?? this.playlists,
        detail: clearDetail ? null : detail ?? this.detail,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        total: total ?? this.total,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final class SongListController extends StateNotifier<SongListState> {
  SongListController(this._service) : super(const SongListState());

  final KuwoPlaylistService _service;
  int _requestId = 0;

  Future<void> loadInitial() async {
    if (state.isLoading || state.playlists.isNotEmpty) return;
    await loadPage(1);
  }

  Future<void> loadPage(int page) async {
    if (page < 1 || state.isLoading) return;
    final requestId = ++_requestId;
    state =
        state.copyWith(isLoading: true, clearError: true, clearDetail: true);
    try {
      final result = await _service.getPopularPlaylists(page);
      if (requestId != _requestId) return;
      state = state.copyWith(
        playlists: result.items,
        page: result.page,
        pageSize: result.pageSize,
        total: result.total,
        isLoading: false,
        clearError: true,
      );
    } on AppFailure catch (error) {
      if (requestId == _requestId) {
        state = state.copyWith(isLoading: false, error: error);
      }
    } on Object catch (error) {
      if (requestId == _requestId) {
        state = state.copyWith(
          isLoading: false,
          error: AppFailure(
            code: AppFailureCode.unknown,
            message: '歌单广场加载失败',
            diagnostic: error.runtimeType.toString(),
          ),
        );
      }
    }
  }

  Future<void> open(OnlinePlaylist playlist) async {
    final requestId = ++_requestId;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final detail = await _service.getPlaylistDetail(playlist);
      if (requestId != _requestId) return;
      state =
          state.copyWith(detail: detail, isLoading: false, clearError: true);
    } on AppFailure catch (error) {
      if (requestId == _requestId) {
        state = state.copyWith(isLoading: false, error: error);
      }
    } on Object catch (error) {
      if (requestId == _requestId) {
        state = state.copyWith(
          isLoading: false,
          error: AppFailure(
            code: AppFailureCode.unknown,
            message: '歌单详情加载失败',
            diagnostic: error.runtimeType.toString(),
          ),
        );
      }
    }
  }

  Future<void> refresh() => state.detail == null
      ? loadPage(state.page)
      : open(state.detail!.playlist);

  void closeDetail() {
    ++_requestId;
    state = state.copyWith(clearDetail: true, clearError: true);
  }

  Future<void> previousPage() => loadPage(state.page - 1);
  Future<void> nextPage() =>
      state.hasNext ? loadPage(state.page + 1) : Future.value();
}
