import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../../leaderboard/data/online_catalog_service.dart';
import '../../leaderboard/state/leaderboard_controller.dart';

final searchProvider = StateNotifierProvider<SearchController, SearchState>(
  (ref) => SearchController(ref.watch(onlineCatalogServiceProvider)),
);

final class SearchState {
  const SearchState({
    this.query = '',
    this.source = OnlineSource.kuwo,
    this.tracks = const [],
    this.page = 1,
    this.pageSize = 30,
    this.total = 0,
    this.isLoading = false,
    this.error,
  });

  final String query;
  final OnlineSource source;
  final List<Track> tracks;
  final int page;
  final int pageSize;
  final int total;
  final bool isLoading;
  final AppFailure? error;

  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < total;

  SearchState copyWith({
    String? query,
    OnlineSource? source,
    List<Track>? tracks,
    int? page,
    int? pageSize,
    int? total,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
  }) =>
      SearchState(
        query: query ?? this.query,
        source: source ?? this.source,
        tracks: tracks ?? this.tracks,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        total: total ?? this.total,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final class SearchController extends StateNotifier<SearchState> {
  SearchController(this._service) : super(const SearchState());

  final OnlineCatalogService _service;
  int _requestId = 0;

  Future<void> submit(String query) => _load(query.trim(), page: 1);

  Future<void> refresh() {
    if (state.query.isEmpty) return Future.value();
    return _load(state.query, page: state.page);
  }

  Future<void> previousPage() {
    if (!state.hasPrevious || state.isLoading) return Future.value();
    return _load(state.query, page: state.page - 1);
  }

  Future<void> nextPage() {
    if (!state.hasNext || state.isLoading) return Future.value();
    return _load(state.query, page: state.page + 1);
  }

  Future<void> _load(String query, {required int page}) async {
    if (query.isEmpty) {
      state = const SearchState();
      return;
    }
    final requestId = ++_requestId;
    state = state.copyWith(
      query: query,
      page: page,
      isLoading: true,
      clearError: true,
    );
    try {
      final result = await _service.searchTracks(state.source, query, page);
      if (requestId != _requestId) return;
      state = state.copyWith(
        query: query,
        tracks: result.items,
        page: result.page,
        pageSize: result.pageSize,
        total: result.total,
        isLoading: false,
        clearError: true,
      );
    } on AppFailure catch (error) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoading: false, error: error);
    } on Object catch (error) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '搜索失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }
}
