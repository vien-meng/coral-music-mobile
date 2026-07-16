import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../data/user_api_runner.dart';
import 'player_controller.dart';

final userApiDebugProvider =
    StateNotifierProvider<UserApiDebugController, UserApiDebugState>(
  (ref) => UserApiDebugController(ref.watch(userApiRunnerProvider)),
);

final class UserApiDebugState {
  const UserApiDebugState({
    this.musicUrlSources = const {},
    this.isLoading = false,
    this.error,
  });

  final Set<String> musicUrlSources;
  final bool isLoading;
  final AppFailure? error;

  UserApiDebugState copyWith({
    Set<String>? musicUrlSources,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
  }) =>
      UserApiDebugState(
        musicUrlSources: musicUrlSources ?? this.musicUrlSources,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final class UserApiDebugController extends StateNotifier<UserApiDebugState> {
  UserApiDebugController(this._runner) : super(const UserApiDebugState());

  final UserApiRunner _runner;

  Future<void> load(String script) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final manifest = await _runner.load(script);
      state = state.copyWith(
        isLoading: false,
        musicUrlSources: manifest.musicUrlSources,
        clearError: true,
      );
    } on AppFailure catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '音源脚本加载失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }
}
