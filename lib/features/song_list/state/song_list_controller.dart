import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import '../data/kuwo_playlist_service.dart';
import '../data/qq_playlist_service.dart';

final playlistCatalogServicesProvider =
    Provider<Map<OnlineSource, PlaylistCatalogService>>(
  (ref) {
    final dio = createHttpClient();
    return {
      OnlineSource.kuwo: KuwoPlaylistService(dio),
      OnlineSource.qq: QqPlaylistService(dio),
    };
  },
);

final songListTagsProvider = FutureProvider<List<PlaylistTag>>(
  (ref) {
    final source = ref.watch(songListProvider.select((state) => state.source));
    final service = ref.watch(playlistCatalogServicesProvider)[source];
    return service?.getTags() ?? Future.value(const []);
  },
);

final songListProvider =
    StateNotifierProvider<SongListController, SongListState>(
  (ref) => SongListController(ref.watch(playlistCatalogServicesProvider)),
);

final class SongListState {
  const SongListState({
    this.source = OnlineSource.kuwo,
    this.playlists = const [],
    this.detail,
    this.page = 1,
    this.pageSize = 30,
    this.total = 0,
    this.selectedTagId,
    this.sortId = 'hot',
    this.query = '',
    this.isLoading = false,
    this.error,
  });

  final OnlineSource source;
  final List<OnlinePlaylist> playlists;
  final PlaylistDetail? detail;
  final int page;
  final int pageSize;
  final int total;
  final String? selectedTagId;
  final String sortId;
  final String query;
  final bool isLoading;
  final AppFailure? error;

  bool get hasNext => page * pageSize < total;

  SongListState copyWith({
    OnlineSource? source,
    List<OnlinePlaylist>? playlists,
    PlaylistDetail? detail,
    int? page,
    int? pageSize,
    int? total,
    String? selectedTagId,
    String? sortId,
    String? query,
    bool clearTag = false,
    bool? isLoading,
    AppFailure? error,
    bool clearDetail = false,
    bool clearError = false,
  }) =>
      SongListState(
        source: source ?? this.source,
        playlists: playlists ?? this.playlists,
        detail: clearDetail ? null : detail ?? this.detail,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        total: total ?? this.total,
        selectedTagId: clearTag ? null : selectedTagId ?? this.selectedTagId,
        sortId: sortId ?? this.sortId,
        query: query ?? this.query,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final class SongListController extends StateNotifier<SongListState> {
  SongListController(this._services) : super(const SongListState());

  final Map<OnlineSource, PlaylistCatalogService> _services;
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
      final service = _serviceFor(state.source);
      final result = state.query.isEmpty
          ? await service.getPopularPlaylists(page,
              tagId: state.selectedTagId, sortId: state.sortId)
          : await service.searchPlaylists(state.query, page);
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
      final detail =
          await _serviceFor(playlist.source).getPlaylistDetail(playlist);
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

  Future<void> selectTag(String? tagId) {
    if (tagId == state.selectedTagId || state.isLoading) return Future.value();
    state = state.copyWith(selectedTagId: tagId, clearTag: tagId == null);
    return loadPage(1);
  }

  Future<void> selectSort(String sortId) {
    if (sortId == state.sortId || state.isLoading) return Future.value();
    state = state.copyWith(sortId: sortId);
    return loadPage(1);
  }

  Future<void> selectSource(OnlineSource source) {
    if (source == state.source || state.isLoading) return Future.value();
    ++_requestId;
    state = SongListState(source: source);
    return loadPage(1);
  }

  Future<void> submitSearch(String query) {
    final normalized = query.trim();
    if (normalized == state.query || state.isLoading) return Future.value();
    state = state.copyWith(query: normalized);
    return loadPage(1);
  }

  PlaylistCatalogService _serviceFor(OnlineSource source) {
    final service = _services[source];
    if (service != null) return service;
    throw AppFailure(
      code: AppFailureCode.invalidData,
      message: '${source.label}暂未接入歌单广场',
    );
  }
}
