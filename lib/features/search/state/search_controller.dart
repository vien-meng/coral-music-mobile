import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import '../../library/data/library_store.dart';
import '../../leaderboard/data/online_catalog_service.dart';
import '../../leaderboard/state/leaderboard_controller.dart';
import '../data/kuwo_hot_search_service.dart';

final kuwoHotSearchServiceProvider = Provider<KuwoHotSearchService>(
  (ref) => KuwoHotSearchService(createHttpClient()),
);

final kuwoHotSearchProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(kuwoHotSearchServiceProvider).load(),
);

final searchProvider = StateNotifierProvider<SearchController, SearchState>(
  (ref) {
    final store = ref.watch(libraryStoreProvider);
    return SearchController(
      ref.watch(onlineCatalogServiceProvider),
      loadHistory: store.listSearchHistory,
      recordHistory: store.recordSearchHistory,
      clearHistory: store.clearSearchHistory,
    );
  },
);

final class SearchState {
  const SearchState({
    this.query = '',
    this.source = OnlineSource.kuwo,
    this.isCombined = false,
    this.tracks = const [],
    this.page = 1,
    this.pageSize = 30,
    this.total = 0,
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  final String query;
  final OnlineSource source;
  final bool isCombined;
  final List<Track> tracks;
  final int page;
  final int pageSize;
  final int total;
  final List<String> history;
  final bool isLoading;
  final AppFailure? error;

  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < total;

  SearchState copyWith({
    String? query,
    OnlineSource? source,
    bool? isCombined,
    List<Track>? tracks,
    int? page,
    int? pageSize,
    int? total,
    List<String>? history,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
  }) =>
      SearchState(
        query: query ?? this.query,
        source: source ?? this.source,
        isCombined: isCombined ?? this.isCombined,
        tracks: tracks ?? this.tracks,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        total: total ?? this.total,
        history: history ?? this.history,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final class SearchController extends StateNotifier<SearchState> {
  SearchController(
    this._service, {
    Future<List<String>> Function()? loadHistory,
    Future<void> Function(String keyword)? recordHistory,
    Future<void> Function()? clearHistory,
  })  : _loadHistory = loadHistory ?? _emptyHistory,
        _recordHistory = recordHistory ?? _discardHistory,
        _clearHistory = clearHistory ?? _discardAllHistory,
        super(const SearchState()) {
    _restoreHistory();
  }

  final OnlineCatalogService _service;
  final Future<List<String>> Function() _loadHistory;
  final Future<void> Function(String keyword) _recordHistory;
  final Future<void> Function() _clearHistory;
  int _requestId = 0;
  var _hasLocalHistoryMutation = false;

  Future<void> submit(String query) {
    final normalized = query.trim();
    if (normalized.isNotEmpty) _saveHistory(normalized);
    return _load(normalized, page: 1);
  }

  Future<void> clearHistory() async {
    _hasLocalHistoryMutation = true;
    state = state.copyWith(history: const []);
    try {
      await _clearHistory();
    } on Object {
      // ponytail: history is convenience data; a failed cleanup must not block search.
    }
  }

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

  Future<void> selectSource(OnlineSource source) {
    if ((source == state.source && !state.isCombined) || state.isLoading) {
      return Future.value();
    }
    final query = state.query;
    ++_requestId;
    state = SearchState(source: source, history: state.history);
    return query.isEmpty ? Future.value() : _load(query, page: 1);
  }

  Future<void> selectCombined() {
    if (state.isCombined || state.isLoading) return Future.value();
    final query = state.query;
    ++_requestId;
    state = SearchState(
      source: state.source,
      isCombined: true,
      history: state.history,
    );
    return query.isEmpty ? Future.value() : _load(query, page: 1);
  }

  Future<void> _load(String query, {required int page}) async {
    if (query.isEmpty) {
      state = SearchState(
        source: state.source,
        isCombined: state.isCombined,
        history: state.history,
      );
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
      final result = state.isCombined
          ? await _searchCombined(query, page)
          : await _service.searchTracks(state.source, query, page);
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

  Future<PageResult<Track>> _searchCombined(String query, int page) async {
    const sources = [
      OnlineSource.kuwo,
      OnlineSource.kugou,
      OnlineSource.qq,
      OnlineSource.netease,
      OnlineSource.migu,
    ];
    AppFailure? firstFailure;
    final results = await Future.wait(
      sources.map((source) async {
        try {
          return await _service.searchTracks(source, query, page);
        } on AppFailure catch (error) {
          firstFailure ??= error;
          return null;
        } on Object {
          firstFailure ??= const AppFailure(
            code: AppFailureCode.unknown,
            message: '综合搜索失败',
          );
          return null;
        }
      }),
    );
    final tracks = <Track>[];
    var total = 0;
    for (final result in results.whereType<PageResult<Track>>()) {
      tracks.addAll(result.items);
      total += result.total;
    }
    if (tracks.isEmpty && firstFailure != null) throw firstFailure!;
    return PageResult(
      items: tracks,
      page: page,
      pageSize: tracks.length,
      total: total,
    );
  }

  Future<void> _restoreHistory() async {
    try {
      final history = await _loadHistory();
      if (!_hasLocalHistoryMutation) {
        state =
            state.copyWith(history: history.take(20).toList(growable: false));
      }
    } on Object {
      // ponytail: a failed history read must not make search unavailable.
    }
  }

  void _saveHistory(String keyword) {
    _hasLocalHistoryMutation = true;
    state = state.copyWith(
      history: [
        keyword,
        ...state.history.where((item) => item != keyword),
      ].take(20).toList(growable: false),
    );
    _recordHistory(keyword).onError((Object _, StackTrace __) {});
  }

  static Future<List<String>> _emptyHistory() async => const [];

  static Future<void> _discardHistory(String _) async {}

  static Future<void> _discardAllHistory() async {}
}
