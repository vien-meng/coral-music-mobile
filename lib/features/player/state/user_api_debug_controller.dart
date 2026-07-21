import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../data/playback_resolver.dart';
import '../data/user_api_runner.dart';
import '../data/user_api_script_fetcher.dart';
import '../data/user_api_source_preferences.dart';
import 'player_controller.dart';

final userApiDebugProvider =
    StateNotifierProvider<UserApiDebugController, UserApiDebugState>(
  (ref) => UserApiDebugController(
    ref.watch(userApiRunnerProvider),
    UserApiScriptFetcher(createHttpClient()),
    ref.watch(playbackResolverProvider),
    UserApiSourcePreferences(),
  ),
);

const defaultUserApiSourceName = '落雪音源';
const defaultUserApiSourceUrl =
    'https://raw.githubusercontent.com/pdone/lx-music-source/main/lx/latest.js';

final class UserApiDebugState {
  const UserApiDebugState({
    this.sources = const [],
    this.activeSourceId,
    this.runtimeRevision = 0,
    this.isLoading = false,
    this.error,
  });

  final List<UserApiSource> sources;
  final String? activeSourceId;
  final int runtimeRevision;
  final bool isLoading;
  final AppFailure? error;

  UserApiSource? get activeSource =>
      sources.where((source) => source.id == activeSourceId).firstOrNull;

  UserApiDebugState copyWith({
    List<UserApiSource>? sources,
    String? activeSourceId,
    bool clearActiveSource = false,
    int? runtimeRevision,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
  }) =>
      UserApiDebugState(
        sources: sources ?? this.sources,
        activeSourceId:
            clearActiveSource ? null : activeSourceId ?? this.activeSourceId,
        runtimeRevision: runtimeRevision ?? this.runtimeRevision,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final class UserApiSource {
  const UserApiSource({
    required this.id,
    required this.name,
    required this.script,
    required this.info,
    required this.musicUrlSources,
    required this.lyricSources,
    this.originUrl,
  });

  final String id;
  final String name;
  final String script;
  final UserApiSourceInfo info;
  final Set<String> musicUrlSources;
  final Set<String> lyricSources;
  final Uri? originUrl;
}

/// Public, comment-header metadata only. It is never executed or persisted.
final class UserApiSourceInfo {
  const UserApiSourceInfo({
    this.name,
    this.description,
    this.version,
    this.author,
    this.homepage,
  });

  final String? name;
  final String? description;
  final String? version;
  final String? author;
  final String? homepage;

  factory UserApiSourceInfo.fromScript(String script) {
    final fields = <String, String>{};
    final tag = RegExp(
      r'^\s*(?:/\*+|\*+|//)\s*@([a-zA-Z]+)\s+(.+?)\s*(?:\*/)?\s*$',
      multiLine: true,
    );
    for (final match in tag.allMatches(script)) {
      final key = match.group(1)!.toLowerCase();
      final value = match.group(2)!.trim();
      if (value.isNotEmpty) fields.putIfAbsent(key, () => value);
    }
    return UserApiSourceInfo(
      name: fields['name'],
      description: fields['description'],
      version: fields['version'],
      author: fields['author'],
      homepage: fields['homepage'] ?? fields['repository'],
    );
  }
}

final class UserApiDebugController extends StateNotifier<UserApiDebugState> {
  UserApiDebugController(
    this._runner, [
    UserApiScriptFetcher? fetcher,
    PlaybackResolver? playbackResolver,
    UserApiSourcePreferences? preferences,
  ])  : _fetcher = fetcher ?? UserApiScriptFetcher(createHttpClient()),
        _playbackResolver = playbackResolver,
        _preferences = preferences ?? UserApiSourcePreferences(),
        super(const UserApiDebugState()) {
    _startupRestore = _restorePersisted();
    _playbackResolver?.setUserApiInitialization(_startupRestore);
  }

  final UserApiRunner _runner;
  final UserApiScriptFetcher _fetcher;
  final PlaybackResolver? _playbackResolver;
  final UserApiSourcePreferences _preferences;
  late final Future<void> _startupRestore;

  /// Returns the single launch restore operation instead of starting another
  /// WebView load while the first one is still in flight.
  Future<void> restorePersisted() => _startupRestore;

  Future<void> _restorePersisted() async {
    ({String name, Uri url})? saved;
    try {
      saved = await _preferences.read();
    } on Object {
      // ponytail: persisted URL sources are optional; unavailable secure storage must not break in-memory imports.
      return;
    }
    if (state.sources.isNotEmpty) return;
    if (saved != null) {
      await importUrl(saved.name, saved.url.toString(), persist: false);
      return;
    }
    await importUrl(
      defaultUserApiSourceName,
      defaultUserApiSourceUrl,
    );
  }

  Future<void> importUrl(String name, String rawUrl,
      {bool persist = true}) async {
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
      await importScript(name, script, originUrl: uri, persist: persist);
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

  Future<void> importBytes(String name, List<int> bytes) async {
    if (bytes.length > UserApiScriptFetcher.maxBytes) {
      state = state.copyWith(
        error: const AppFailure(
          code: AppFailureCode.invalidData,
          message: '音源脚本超过大小限制',
        ),
      );
      return;
    }
    try {
      await importScript(name, utf8.decode(bytes));
    } on FormatException {
      state = state.copyWith(
        error: const AppFailure(
          code: AppFailureCode.invalidData,
          message: '音源脚本不是 UTF-8 文本',
        ),
      );
    }
  }

  Future<void> importScript(
    String name,
    String script, {
    Uri? originUrl,
    bool persist = true,
  }) async {
    final info = UserApiSourceInfo.fromScript(script);
    final normalizedName =
        name.trim().isNotEmpty ? name.trim() : info.name ?? '未命名音源';
    final previous = state.activeSource;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final manifest = await _runner.load(script);
      final source = UserApiSource(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: normalizedName,
        script: script,
        info: info,
        musicUrlSources: manifest.musicUrlSources,
        lyricSources: manifest.lyricSources,
        originUrl: originUrl,
      );
      _playbackResolver?.clear();
      if (persist && originUrl != null) {
        await _preferences.save(normalizedName, originUrl);
      } else if (persist) {
        await _preferences.clear();
      }
      state = state.copyWith(
        isLoading: false,
        sources: [...state.sources, source],
        activeSourceId: source.id,
        runtimeRevision: state.runtimeRevision + 1,
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
        info: target.info,
        musicUrlSources: manifest.musicUrlSources,
        lyricSources: manifest.lyricSources,
        originUrl: target.originUrl,
      );
      _playbackResolver?.clear();
      if (target.originUrl != null) {
        await _preferences.save(target.name, target.originUrl!);
      } else {
        await _preferences.clear();
      }
      state = state.copyWith(
        isLoading: false,
        sources: [
          for (final source in state.sources)
            source.id == id ? updated : source,
        ],
        activeSourceId: id,
        runtimeRevision: state.runtimeRevision + 1,
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

  Future<void> refresh(String id) async {
    final target = state.sources.where((source) => source.id == id).firstOrNull;
    if (target == null ||
        target.id != state.activeSourceId ||
        target.originUrl == null) {
      return;
    }
    final previous = target;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final script = await _fetcher.fetch(target.originUrl!);
      final manifest = await _runner.load(script);
      final info = UserApiSourceInfo.fromScript(script);
      final updated = UserApiSource(
        id: target.id,
        name: target.name,
        script: script,
        info: info,
        musicUrlSources: manifest.musicUrlSources,
        lyricSources: manifest.lyricSources,
        originUrl: target.originUrl,
      );
      _playbackResolver?.clear();
      state = state.copyWith(
        isLoading: false,
        sources: [
          for (final source in state.sources)
            source.id == target.id ? updated : source,
        ],
        runtimeRevision: state.runtimeRevision + 1,
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
          message: '音源刷新失败',
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
      _playbackResolver?.clear();
      await _preferences.clear();
      state = state.copyWith(
        isLoading: false,
        sources: state.sources.where((item) => item.id != id).toList(),
        clearActiveSource: true,
        runtimeRevision: state.runtimeRevision + 1,
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
