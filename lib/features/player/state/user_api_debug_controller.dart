import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../core/http_client.dart';
import '../../../domain/music.dart';
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

// Kept only to remove the record written by versions that auto-configured it.
const _removedDefaultUserApiSourceName = '落雪音源';
const _removedDefaultUserApiSourceUrl =
    'https://raw.githubusercontent.com/pdone/lx-music-source/main/lx/latest.js';
final _removedDefaultUserApiSourceUri =
    Uri.parse(_removedDefaultUserApiSourceUrl);

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
    required this.musicUrlQualities,
    this.originUrl,
  });

  final String id;
  final String name;
  final String script;
  final UserApiSourceInfo info;
  final Set<String> musicUrlSources;
  final Map<String, Set<AudioQuality>> musicUrlQualities;
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
  Future<void>? _runtimeRestore;

  /// Returns the single launch restore operation instead of starting another
  /// WebView load while the first one is still in flight.
  Future<void> restorePersisted() => _startupRestore;

  /// Re-loads the active script after the app returns to the foreground.
  /// iOS may discard WKWebView's content process while the app is suspended.
  Future<void> restoreRuntime() {
    final source = state.activeSource;
    if (source == null || state.isLoading) return Future.value();
    return _runtimeRestore ??= _reloadRuntime(source);
  }

  Future<void> _reloadRuntime(UserApiSource source) async {
    try {
      await _runner.load(source.script);
    } on AppFailure catch (error) {
      if (state.activeSourceId == source.id && !state.isLoading) {
        state = state.copyWith(error: error);
      }
    } on Object catch (error) {
      if (state.activeSourceId == source.id && !state.isLoading) {
        state = state.copyWith(
          error: AppFailure(
            code: AppFailureCode.unknown,
            message: '音源恢复失败',
            diagnostic: error.runtimeType.toString(),
          ),
        );
      }
    } finally {
      _runtimeRestore = null;
    }
  }

  Future<void> _restorePersisted() async {
    UserApiSavedSources? savedSources;
    ({String name, Uri url})? saved;
    ({String name, String script})? local;
    try {
      savedSources = await _preferences.readSources();
      saved = await _preferences.read();
      local = await _preferences.readLocalScript();
    } on Object {
      // ponytail: unavailable secure storage leaves the session without a source.
      saved = null;
      local = null;
    }
    if (state.sources.isNotEmpty) return;
    if (savedSources != null) {
      await _restoreSources(savedSources);
      return;
    }
    if (local != null) {
      await importScript(local.name, local.script,
          persist: false, cache: false);
      await _persistSources(state.sources, state.activeSourceId);
      return;
    }
    if (saved == null) return;
    if (saved.name == _removedDefaultUserApiSourceName &&
        saved.url == _removedDefaultUserApiSourceUri) {
      await _preferences.clear();
      return;
    }
    await _restoreUrl(saved.name, saved.url, persist: false);
    await _persistSources(state.sources, state.activeSourceId);
  }

  Future<void> _restoreSources(UserApiSavedSources saved) async {
    for (final source in saved.sources) {
      await importScript(
        source.name,
        source.script,
        originUrl: source.originUrl,
        persist: false,
        cache: false,
        sourceId: source.id,
      );
    }
    final activeId = saved.activeSourceId;
    if (activeId != null && activeId != state.activeSourceId) {
      await _activate(activeId, persist: false);
    }
  }

  Future<void> _restoreUrl(String name, Uri url,
      {required bool persist}) async {
    final cached = await _preferences.readCachedScript(url);
    if (cached != null) {
      await importScript(name, cached,
          originUrl: url, persist: persist, cache: false);
      if (state.sources.any((source) => source.originUrl == url)) return;
    }
    await importUrl(name, url.toString(), persist: persist);
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
    bool cache = true,
    String? sourceId,
  }) async {
    final info = UserApiSourceInfo.fromScript(script);
    final suppliedName = name.trim();
    final normalizedName =
        info.name != null && suppliedName.startsWith('coral-import-')
            ? info.name!
            : suppliedName.isNotEmpty
                ? suppliedName
                : info.name ?? '未命名音源';
    final previous = state.activeSource;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final manifest = await _runner.load(script);
      final source = UserApiSource(
        id: sourceId ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: normalizedName,
        script: script,
        info: info,
        musicUrlSources: manifest.musicUrlSources,
        musicUrlQualities: manifest.musicUrlQualities,
        originUrl: originUrl,
      );
      _playbackResolver?.clear();
      if (cache && originUrl != null) {
        await _preferences.cacheScript(originUrl, script);
      }
      final sources = [...state.sources, source];
      if (persist) await _persistSources(sources, source.id);
      state = state.copyWith(
        isLoading: false,
        sources: sources,
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

  Future<void> activate(String id) => _activate(id);

  Future<void> _activate(String id, {bool persist = true}) async {
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
        musicUrlQualities: manifest.musicUrlQualities,
        originUrl: target.originUrl,
      );
      _playbackResolver?.clear();
      final sources = [
        for (final source in state.sources) source.id == id ? updated : source,
      ];
      if (persist) await _persistSources(sources, id);
      state = state.copyWith(
        isLoading: false,
        sources: sources,
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
        musicUrlQualities: manifest.musicUrlQualities,
        originUrl: target.originUrl,
      );
      _playbackResolver?.clear();
      await _preferences.cacheScript(target.originUrl!, script);
      final sources = [
        for (final source in state.sources)
          source.id == target.id ? updated : source,
      ];
      await _persistSources(sources, target.id);
      state = state.copyWith(
        isLoading: false,
        sources: sources,
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
    final remaining = state.sources.where((item) => item.id != id).toList();
    if (id != state.activeSourceId) {
      await _persistSources(remaining, state.activeSourceId);
      state = state.copyWith(
        sources: remaining,
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _runner.clear();
      _playbackResolver?.clear();
      await _persistSources(remaining, null);
      state = state.copyWith(
        isLoading: false,
        sources: remaining,
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

  Future<void> _persistSources(
    List<UserApiSource> sources,
    String? activeSourceId,
  ) =>
      _preferences.saveSources(
        [
          for (final source in sources)
            UserApiSavedSource(
              id: source.id,
              name: source.name,
              script: source.script,
              originUrl: source.originUrl,
            ),
        ],
        activeSourceId: activeSourceId,
      );
}
