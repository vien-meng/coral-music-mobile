import 'dart:convert';

import 'package:coral_music_mobile/core/app_failure.dart';
import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/playback_resolver.dart';
import 'package:coral_music_mobile/features/player/data/user_api_runner.dart';
import 'package:coral_music_mobile/features/player/data/user_api_script_fetcher.dart';
import 'package:coral_music_mobile/features/player/data/user_api_source_preferences.dart';
import 'package:coral_music_mobile/features/player/state/user_api_debug_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imports, activates and removes User API sources', () async {
    final runner = _Runner();
    final controller = await _sessionController(runner);

    await controller.importScript('酷我音源', 'kw-script');
    await controller.importScript('QQ 音源', 'qq-script');

    expect(controller.state.sources, hasLength(2));
    expect(controller.state.activeSource?.name, 'QQ 音源');
    expect(controller.state.activeSource?.musicUrlSources, {'qq'});

    final kuwoId = controller.state.sources
        .firstWhere((source) => source.name == '酷我音源')
        .id;
    await controller.activate(kuwoId);
    expect(controller.state.activeSource?.name, '酷我音源');
    expect(runner.loadedScript, 'kw-script');

    await controller.remove(kuwoId);
    expect(controller.state.activeSource, isNull);
    expect(runner.wasCleared, isTrue);
  });

  test('uses public script header details instead of a generated source name',
      () async {
    final controller = await _sessionController(_Runner());

    await controller.importScript('', '''
/*!
 * @name [独家音源]
 * @description 音源更新，关注微信公众号：洛雪科技
 * @version 4
 * @author 洛雪科技
 * @repository https://github.com/lxmusics/lx-music-api-server
 */
kw-script
''');

    final source = controller.state.activeSource!;
    expect(source.name, '[独家音源]');
    expect(source.info.description, '音源更新，关注微信公众号：洛雪科技');
    expect(source.info.version, '4');
    expect(source.info.author, '洛雪科技');
    expect(source.info.homepage,
        'https://github.com/lxmusics/lx-music-api-server');
  });

  test('clears cached URLs after the active source changes', () async {
    final runner = _Runner();
    final resolver = PlaybackResolver(runner);
    final controller = UserApiDebugController(
      runner,
      _Fetcher('kw-default-script'),
      resolver,
      _UnavailablePreferences(),
    );
    await controller.restorePersisted();
    const track = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: 'cache-test',
      title: '缓存测试',
      artist: '珊瑚音乐',
    );

    await controller.importScript('版本一', 'kw-v1');
    await resolver.resolve(track);
    await controller.importScript('版本二', 'kw-v2');
    await resolver.resolve(track);

    expect(runner.resolveCount, 2);
  });

  test('reloads the active source when restoring its runtime', () async {
    final runner = _Runner();
    final controller = await _sessionController(runner);
    await controller.importScript('酷我音源', 'kw-script');

    await controller.restoreRuntime();

    expect(runner.loadedScript, 'kw-script');
    expect(runner.loadCount, 2);
  });

  test('imports UTF-8 script bytes and rejects an oversized file', () async {
    final controller = await _sessionController(_Runner());

    await controller.importBytes('文件音源', utf8.encode('kw-script'));
    expect(controller.state.activeSource?.name, '文件音源');

    await controller.importBytes('', List.filled(256 * 1024 + 1, 0));
    expect(controller.state.error?.message, '音源脚本超过大小限制');
  });

  test('restores a script imported from a local JS file', () async {
    final preferences = _LocalScriptPreferences('文件音源', 'kw-local-script');
    final controller = UserApiDebugController(
      _Runner(),
      _Fetcher('kw-default-script'),
      null,
      preferences,
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource?.name, '文件音源');
    expect(controller.state.activeSource?.script, 'kw-local-script');
  });

  test('persists a script imported from a local JS file', () async {
    final preferences = _SavedSourcesPreferences();
    final controller = UserApiDebugController(
      _Runner(),
      _Fetcher('kw-default-script'),
      null,
      preferences,
    );

    await controller.importBytes('文件音源', utf8.encode('kw-local-script'));

    expect(preferences.value?.sources.single.name, '文件音源');
    expect(preferences.value?.sources.single.script, 'kw-local-script');
  });

  test('restores every JS file source and its active selection', () async {
    final preferences = _SavedSourcesPreferences();
    final imported = UserApiDebugController(
      _Runner(),
      _Fetcher('unused'),
      null,
      preferences,
    );
    await imported.restorePersisted();
    await imported.importBytes('酷我文件音源', utf8.encode('kw-file-script'));
    await imported.importBytes('QQ 文件音源', utf8.encode('qq-file-script'));

    final restored = UserApiDebugController(
      _Runner(),
      _Fetcher('unused'),
      null,
      preferences,
    );
    await restored.restorePersisted();

    expect(restored.state.sources.map((source) => source.name), [
      '酷我文件音源',
      'QQ 文件音源',
    ]);
    expect(restored.state.activeSource?.name, 'QQ 文件音源');

    final firstId = restored.state.sources.first.id;
    await restored.activate(firstId);
    final restarted = UserApiDebugController(
      _Runner(),
      _Fetcher('unused'),
      null,
      preferences,
    );
    await restarted.restorePersisted();

    expect(restarted.state.sources, hasLength(2));
    expect(restarted.state.activeSource?.name, '酷我文件音源');
  });

  test('restores every URL source from its saved local script', () async {
    final firstUrl = Uri.parse('https://example.com/kw.js');
    final secondUrl = Uri.parse('https://example.com/qq.js');
    final preferences = _SavedSourcesPreferences();
    final imported = UserApiDebugController(
      _Runner(),
      _MappingFetcher({
        firstUrl: 'kw-url-script',
        secondUrl: 'qq-url-script',
      }),
      null,
      preferences,
    );
    await imported.restorePersisted();
    await imported.importUrl('酷我 URL 音源', firstUrl.toString());
    await imported.importUrl('QQ URL 音源', secondUrl.toString());

    final restored = UserApiDebugController(
      _Runner(),
      _FailingFetcher(),
      null,
      preferences,
    );
    await restored.restorePersisted();

    expect(restored.state.sources.map((source) => source.name), [
      '酷我 URL 音源',
      'QQ URL 音源',
    ]);
    expect(restored.state.activeSource?.name, 'QQ URL 音源');
    expect(restored.state.error, isNull);
  });

  test('does not load a source when no source is configured', () async {
    final preferences = _Preferences();
    final fetcher = _Fetcher('kw-default-script');
    final controller = UserApiDebugController(
      _Runner(),
      fetcher,
      null,
      preferences,
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource, isNull);
    expect(fetcher.urls, isEmpty);
    expect(preferences.saved, isEmpty);
  });

  test('does not load a source when persisted storage is unavailable',
      () async {
    final fetcher = _Fetcher('kw-default-script');
    final controller = UserApiDebugController(
      _Runner(),
      fetcher,
      null,
      _UnavailablePreferences(),
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource, isNull);
    expect(fetcher.urls, isEmpty);
  });

  test('clears the source record written by the removed default source',
      () async {
    final preferences = _Preferences(
      (
        name: '落雪音源',
        url: Uri.parse(
          'https://raw.githubusercontent.com/pdone/lx-music-source/main/lx/latest.js',
        ),
      ),
    );
    final fetcher = _Fetcher('kw-default-script');
    final controller = UserApiDebugController(
      _Runner(),
      fetcher,
      null,
      preferences,
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource, isNull);
    expect(fetcher.urls, isEmpty);
    expect(preferences.clearCount, 1);
  });

  test('restores a cached source script before requesting the network',
      () async {
    final saved = (name: '缓存音源', url: Uri.parse('https://example.com/me.js'));
    final preferences = _CachingPreferences('kw-cached-script', saved);
    final fetcher = _Fetcher('kw-network-script');
    final controller = UserApiDebugController(
      _Runner(),
      fetcher,
      null,
      preferences,
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource?.name, saved.name);
    expect(controller.state.activeSource?.script, 'kw-cached-script');
    expect(fetcher.urls, isEmpty);
  });

  test('caches a fetched source script after it has initialized', () async {
    final preferences = _CachingPreferences(null, null);
    final controller = UserApiDebugController(
      _Runner(),
      _Fetcher('kw-network-script'),
      null,
      preferences,
    );
    final url = Uri.parse('https://example.com/source.js');

    await controller.restorePersisted();
    preferences.cached = null;
    await controller.importUrl('测试音源', url.toString());

    expect(preferences.cached, (url: url, script: 'kw-network-script'));
  });

  test('restores the saved source without adding another source', () async {
    final saved = (name: '我的音源', url: Uri.parse('https://example.com/me.js'));
    final preferences = _Preferences(saved);
    final fetcher = _Fetcher('kw-saved-script');
    final controller = UserApiDebugController(
      _Runner(),
      fetcher,
      null,
      preferences,
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource?.name, saved.name);
    expect(controller.state.sources.map((source) => source.name), [saved.name]);
    expect(fetcher.urls, [saved.url]);
    expect(preferences.saved, isEmpty);
  });

  test('removes an imported URL source', () async {
    final preferences = _Preferences();
    final controller = UserApiDebugController(
      _Runner(),
      _Fetcher('kw-script'),
      null,
      preferences,
    );
    await controller.importUrl('我的音源', 'https://example.com/me.js');
    final source = controller.state.sources.single;

    await controller.remove(source.id);

    expect(controller.state.sources, isEmpty);
    expect(controller.state.activeSource, isNull);
    expect(preferences.clearCount, 1);
  });

  test('a saved source failure completes startup restore without a source',
      () async {
    final saved = (name: '失效音源', url: Uri.parse('https://example.com/me.js'));
    final controller = UserApiDebugController(
      _Runner(),
      _FailingFetcher(),
      null,
      _Preferences(saved),
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource, isNull);
    expect(controller.state.error?.message, '保存的音源不可用');
  });
}

Future<UserApiDebugController> _sessionController(_Runner runner) async {
  final controller = UserApiDebugController(
    runner,
    _Fetcher('kw-default-script'),
    null,
    _UnavailablePreferences(),
  );
  await controller.restorePersisted();
  return controller;
}

final class _UnavailablePreferences extends UserApiSourcePreferences {
  @override
  Future<({String name, Uri url})?> read() =>
      Future.error(StateError('No persisted source for this test.'));

  @override
  Future<void> clear() async {}

  @override
  Future<void> saveSources(List<UserApiSavedSource> sources,
      {String? activeSourceId}) async {}
}

final class _Preferences extends UserApiSourcePreferences {
  _Preferences([this.value]);

  final ({String name, Uri url})? value;
  final saved = <({String name, Uri url})>[];
  var clearCount = 0;

  @override
  Future<({String name, Uri url})?> read() async => value;

  @override
  Future<void> save(String name, Uri url) async {
    saved.add((name: name, url: url));
  }

  @override
  Future<void> saveSources(List<UserApiSavedSource> sources,
      {String? activeSourceId}) async {
    if (sources.isEmpty) await clear();
  }

  @override
  Future<void> clear() async => clearCount++;
}

final class _CachingPreferences extends UserApiSourcePreferences {
  _CachingPreferences(this.script, this.value);

  final String? script;
  final ({String name, Uri url})? value;
  ({Uri url, String script})? cached;

  @override
  Future<({String name, Uri url})?> read() async => value;

  @override
  Future<void> save(String name, Uri url) async {}

  @override
  Future<void> saveSources(List<UserApiSavedSource> sources,
      {String? activeSourceId}) async {}

  @override
  Future<String?> readCachedScript(Uri url) async => script;

  @override
  Future<void> cacheScript(Uri url, String script) async {
    cached = (url: url, script: script);
  }
}

final class _LocalScriptPreferences extends UserApiSourcePreferences {
  _LocalScriptPreferences(this.name, this.script);

  final String name;
  final String script;

  @override
  Future<({String name, String script})?> readLocalScript() async =>
      (name: name, script: script);

  @override
  Future<void> saveSources(List<UserApiSavedSource> sources,
      {String? activeSourceId}) async {}
}

final class _SavedSourcesPreferences extends UserApiSourcePreferences {
  UserApiSavedSources? value;

  @override
  Future<UserApiSavedSources?> readSources() async => value;

  @override
  Future<void> saveSources(
    List<UserApiSavedSource> sources, {
    String? activeSourceId,
  }) async {
    value = UserApiSavedSources(
      sources: List.of(sources),
      activeSourceId: activeSourceId,
    );
  }

  @override
  Future<void> clear() async => value = null;
}

final class _Fetcher extends UserApiScriptFetcher {
  _Fetcher(this.script) : super(Dio());

  final String script;
  final urls = <Uri>[];

  @override
  Future<String> fetch(Uri uri) async {
    urls.add(uri);
    return script;
  }
}

final class _MappingFetcher extends UserApiScriptFetcher {
  _MappingFetcher(this.scripts) : super(Dio());

  final Map<Uri, String> scripts;

  @override
  Future<String> fetch(Uri uri) async => scripts[uri]!;
}

final class _FailingFetcher extends UserApiScriptFetcher {
  _FailingFetcher() : super(Dio());

  @override
  Future<String> fetch(Uri uri) async => throw const AppFailure(
        code: AppFailureCode.noNetwork,
        message: '保存的音源不可用',
      );
}

final class _Runner implements UserApiRunner {
  String? loadedScript;
  bool wasCleared = false;
  var loadCount = 0;
  var resolveCount = 0;

  @override
  Future<void> clear() async {
    wasCleared = true;
    loadedScript = null;
  }

  @override
  Future<UserApiManifest> load(String script) async {
    loadCount++;
    loadedScript = script;
    return UserApiManifest({script.startsWith('kw') ? 'kw' : 'qq'});
  }

  @override
  Future<ResolvedPlaybackUrl> resolveMusicUrl(
    Track track,
    AudioQuality quality,
  ) async =>
      ResolvedPlaybackUrl(
        Uri.parse('https://example.com/audio-${++resolveCount}.mp3'),
      );
}
