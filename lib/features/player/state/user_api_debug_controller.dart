import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../data/user_api_runner.dart';
import '../data/user_api_script_fetcher.dart';
import 'player_controller.dart';

final userApiDebugProvider =
    StateNotifierProvider<UserApiDebugController, UserApiDebugState>(
  (ref) => UserApiDebugController(
    ref.watch(userApiRunnerProvider),
    UserApiScriptFetcher(createHttpClient()),
  ),
);

final class UserApiDebugState {
  const UserApiDebugState({
    this.sources = const [],
    this.activeSourceId,
    this.isLoading = false,
    this.error,
  });

  final List<UserApiSource> sources;
  final String? activeSourceId;
  final bool isLoading;
  final AppFailure? error;

  UserApiSource? get activeSource =>
      sources.where((source) => source.id == activeSourceId).firstOrNull;

  UserApiDebugState copyWith({
    List<UserApiSource>? sources,
    String? activeSourceId,
    bool clearActiveSource = false,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
  }) =>
      UserApiDebugState(
        sources: sources ?? this.sources,
        activeSourceId:
            clearActiveSource ? null : activeSourceId ?? this.activeSourceId,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final class UserApiSource {
  const UserApiSource({
    required this.id,
    required this.name,
    required this.script,
    required this.musicUrlSources,
    required this.lyricSources,
  });

  final String id;
  final String name;
  final String script;
  final Set<String> musicUrlSources;
  final Set<String> lyricSources;
}

final class UserApiDebugController extends StateNotifier<UserApiDebugState> {
  UserApiDebugController(this._runner, [UserApiScriptFetcher? fetcher])
      : _fetcher = fetcher ?? UserApiScriptFetcher(createHttpClient()),
        super(const UserApiDebugState());

  final UserApiRunner _runner;
  final UserApiScriptFetcher _fetcher;

  Future<void> importUrl(String name, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      state = state.copyWith(
        error: const AppFailure(
          code: AppFailureCode.invalidData,
          message: '音源地址必须使用 HTTPS',
        ),
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final script = await _fetcher.fetch(uri);
      await importScript(name, script);
    } on AppFailure catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '音源脚本下载失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> importScript(String name, String script) async {
    final normalizedName =
        name.trim().isEmpty ? '音源 ${state.sources.length + 1}' : name.trim();
    final previous = state.activeSource;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final manifest = await _runner.load(script);
      final source = UserApiSource(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: normalizedName,
        script: script,
        musicUrlSources: manifest.musicUrlSources,
        lyricSources: manifest.lyricSources,
      );
      state = state.copyWith(
        isLoading: false,
        sources: [...state.sources, source],
        activeSourceId: source.id,
        clearError: true,
      );
    } on AppFailure catch (error) {
      await _restore(previous);
      state = state.copyWith(isLoading: false, error: error);
    } on Object catch (error) {
      await _restore(previous);
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

  Future<void> activate(String id) async {
    final target = state.sources.where((source) => source.id == id).firstOrNull;
    if (target == null || target.id == state.activeSourceId) return;
    final previous = state.activeSource;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final manifest = await _runner.load(target.script);
      final updated = UserApiSource(
        id: target.id,
        name: target.name,
        script: target.script,
        musicUrlSources: manifest.musicUrlSources,
        lyricSources: manifest.lyricSources,
      );
      state = state.copyWith(
        isLoading: false,
        sources: [
          for (final source in state.sources)
            source.id == id ? updated : source,
        ],
        activeSourceId: id,
        clearError: true,
      );
    } on AppFailure catch (error) {
      await _restore(previous);
      state = state.copyWith(isLoading: false, error: error);
    } on Object catch (error) {
      await _restore(previous);
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '音源启用失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> remove(String id) async {
    final source = state.sources.where((item) => item.id == id).firstOrNull;
    if (source == null) return;
    if (id != state.activeSourceId) {
      state = state.copyWith(
        sources: state.sources.where((item) => item.id != id).toList(),
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _runner.clear();
      state = state.copyWith(
        isLoading: false,
        sources: state.sources.where((item) => item.id != id).toList(),
        clearActiveSource: true,
        clearError: true,
      );
    } on AppFailure catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: AppFailure(
          code: AppFailureCode.unknown,
          message: '音源移除失败',
          diagnostic: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> _restore(UserApiSource? source) async {
    try {
      if (source == null) {
        await _runner.clear();
        return;
      }
      await _runner.load(source.script);
    } on Object {
      // 恢复失败不覆盖当前导入/启用操作的原始错误。
    }
  }
}
