import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
import '../data/kuwo_catalog_service.dart';
import '../data/migu_catalog_service.dart';
import '../data/netease_catalog_service.dart';
import '../data/online_catalog_service.dart';
import '../data/qq_catalog_service.dart';

final onlineCatalogServiceProvider = Provider<OnlineCatalogService>(
  (ref) {
    final dio = createHttpClient();
    return MultiSourceOnlineCatalogService({
      OnlineSource.kuwo: KuwoCatalogService(dio),
      OnlineSource.qq: QqCatalogService(dio),
      OnlineSource.migu: MiguCatalogService(dio),
      OnlineSource.netease: NeteaseCatalogService(dio),
    });
  },
);

final leaderboardProvider =
    StateNotifierProvider<LeaderboardController, LeaderboardState>(
  (ref) => LeaderboardController(ref.watch(onlineCatalogServiceProvider)),
);

final class LeaderboardState {
  const LeaderboardState({
    this.source = OnlineSource.kuwo,
    this.boards = const [],
    this.activeBoard,
    this.tracks = const [],
    this.page = 1,
    this.pageSize = 100,
    this.total = 0,
    this.isLoading = false,
    this.error,
  });

  final OnlineSource source;
  final List<LeaderboardBoard> boards;
  final LeaderboardBoard? activeBoard;
  final List<Track> tracks;
  final int page;
  final int pageSize;
  final int total;
  final bool isLoading;
  final AppFailure? error;

  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < total;

  LeaderboardState copyWith({
    OnlineSource? source,
    List<LeaderboardBoard>? boards,
    LeaderboardBoard? activeBoard,
    List<Track>? tracks,
    int? page,
    int? pageSize,
    int? total,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
  }) =>
      LeaderboardState(
        source: source ?? this.source,
        boards: boards ?? this.boards,
        activeBoard: activeBoard ?? this.activeBoard,
        tracks: tracks ?? this.tracks,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        total: total ?? this.total,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final class LeaderboardController extends StateNotifier<LeaderboardState> {
  LeaderboardController(this._service) : super(const LeaderboardState());

  final OnlineCatalogService _service;
  int _requestId = 0;

  Future<void> loadInitial() async {
    if (state.isLoading || state.boards.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final boards = await _service.getLeaderboardBoards(state.source);
      if (boards.isEmpty) {
        state = state.copyWith(
          boards: boards,
          isLoading: false,
          error: const AppFailure(
            code: AppFailureCode.invalidData,
            message: '暂无可用榜单',
          ),
        );
        return;
      }
      state = state.copyWith(boards: boards, isLoading: false);
      await selectBoard(boards.first);
    } on AppFailure catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '榜单加载失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> selectBoard(LeaderboardBoard board, {int page = 1}) async {
    final requestId = ++_requestId;
    state = state.copyWith(
      activeBoard: board,
      page: page,
      isLoading: true,
      clearError: true,
    );
    try {
      final result = await _service.getLeaderboardDetail(
        board.source,
        board.id,
        page,
      );
      if (requestId != _requestId) return;
      state = state.copyWith(
        activeBoard: board,
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
          message: '榜单加载失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> refresh() async {
    final board = state.activeBoard;
    if (board == null) return loadInitial();
    return selectBoard(board, page: state.page);
  }

  Future<void> selectSource(OnlineSource source) async {
    if (source == state.source || state.isLoading) return;
    ++_requestId;
    state = LeaderboardState(source: source, isLoading: true);
    try {
      final boards = await _service.getLeaderboardBoards(source);
      if (boards.isEmpty) {
        state = state.copyWith(
          boards: boards,
          isLoading: false,
          error: const AppFailure(
            code: AppFailureCode.invalidData,
            message: '暂无可用榜单',
          ),
        );
        return;
      }
      state = state.copyWith(boards: boards, isLoading: false);
      await selectBoard(boards.first);
    } on AppFailure catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '榜单加载失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> previousPage() async {
    final board = state.activeBoard;
    if (board == null || !state.hasPrevious || state.isLoading) return;
    await selectBoard(board, page: state.page - 1);
  }

  Future<void> nextPage() async {
    final board = state.activeBoard;
    if (board == null || !state.hasNext || state.isLoading) return;
    await selectBoard(board, page: state.page + 1);
  }
}
