import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import '../data/kuwo_playlist_service.dart';
import '../data/migu_playlist_service.dart';
import '../data/qq_playlist_service.dart';

final playlistCatalogServicesProvider =
    Provider<Map<OnlineSource, PlaylistCatalogService>>(
  (ref) {
    final dio = createHttpClient();
    return {
      OnlineSource.kuwo: KuwoPlaylistService(dio),
      OnlineSource.qq: QqPlaylistService(dio),
      OnlineSource.migu: MiguPlaylistService(dio),
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
  Future<void>? _artworkResolution;
  final _artworkListeners = <void Function(Track)>[];

  Future<void> loadInitial() async {
    if (state.isLoading || state.playlists.isNotEmpty || state.detail != null) {
      return;
    }
    await loadPage(1);
  }

  Future<void> loadPage(int page, {bool append = false}) async {
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
        playlists: append
            ? mergePlaylistPages(state.playlists, result.items)
            : result.items,
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
      unawaited(resolveAllTrackArtwork());
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

  Future<Track> resolveTrackArtwork(Track track) async {
    if (track.coverUri != null || track.sourceId != OnlineSource.kuwo.id) {
      return track;
    }
    final service = _services[OnlineSource.kuwo];
    if (service is! KuwoPlaylistService) return track;
    final resolved = await service.resolveTrackArtwork(
      track,
      fallbackCover: state.detail?.playlist.coverUri,
    );
    if (resolved.coverUri == track.coverUri) return resolved;
    final detail = state.detail;
    if (detail == null) return resolved;
    final index = detail.tracks.indexWhere((item) => item.id == track.id);
    if (index < 0) return resolved;
    final tracks = [...detail.tracks]..[index] = resolved;
    state = state.copyWith(
      detail: PlaylistDetail(playlist: detail.playlist, tracks: tracks),
    );
    return resolved;
  }

  Future<void> resolveAllTrackArtwork([void Function(Track)? onResolved]) {
    if (onResolved != null) _artworkListeners.add(onResolved);
    return _artworkResolution ??= _resolveAllTrackArtwork().whenComplete(() {
      _artworkResolution = null;
      _artworkListeners.clear();
    });
  }

  Future<void> _resolveAllTrackArtwork() async {
    final detail = state.detail;
    if (detail == null || detail.playlist.source != OnlineSource.kuwo) return;
    final tracks = detail.tracks;
    // ponytail: three concurrent lookups keep the public search endpoint responsive; raise only with measured need.
    for (var index = 0; index < tracks.length; index += 3) {
      final batch = tracks.skip(index).take(3);
      await Future.wait(
        batch.map((track) async {
          final resolved = await resolveTrackArtwork(track);
          for (final listener in _artworkListeners) {
            listener(resolved);
          }
        }),
      );
    }
  }

  Future<void> refresh() =>
      state.detail == null ? loadPage(1) : open(state.detail!.playlist);

  void closeDetail() {
    ++_requestId;
    state = state.copyWith(clearDetail: true, clearError: true);
  }

  Future<void> loadMore() =>
      state.hasNext ? loadPage(state.page + 1, append: true) : Future.value();

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

List<OnlinePlaylist> mergePlaylistPages(
  Iterable<OnlinePlaylist> current,
  Iterable<OnlinePlaylist> next,
) {
  final merged = current.toList();
  final ids = merged.map((item) => '${item.source.id}:${item.id}').toSet();
  for (final item in next) {
    if (ids.add('${item.source.id}:${item.id}')) merged.add(item);
  }
  return merged;
}
