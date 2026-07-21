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

  test('imports, activates and removes session-only User API sources',
      () async {
    final runner = _Runner();
    final controller = await _sessionController(runner);

    await controller.importScript('酷我音源', 'kw-script');
    await controller.importScript('QQ 音源', 'qq-script');

    expect(controller.state.sources, hasLength(3));
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

  test('imports UTF-8 script bytes and rejects an oversized file', () async {
    final controller = await _sessionController(_Runner());

    await controller.importBytes('文件音源', utf8.encode('kw-script'));
    expect(controller.state.activeSource?.name, '文件音源');

    await controller.importBytes('', List.filled(256 * 1024 + 1, 0));
    expect(controller.state.error?.message, '音源脚本超过大小限制');
  });

  test('loads and saves the default LX source when no source is configured',
      () async {
    final preferences = _Preferences();
    final fetcher = _Fetcher('kw-default-script');
    final controller = UserApiDebugController(
      _Runner(),
      fetcher,
      null,
      preferences,
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource?.name, defaultUserApiSourceName);
    expect(fetcher.urls, [Uri.parse(defaultUserApiSourceUrl)]);
    expect(preferences.saved, [
      (name: defaultUserApiSourceName, url: Uri.parse(defaultUserApiSourceUrl)),
    ]);
  });

  test('loads the default LX source when persisted storage is unavailable',
      () async {
    final fetcher = _Fetcher('kw-default-script');
    final controller = UserApiDebugController(
      _Runner(),
      fetcher,
      null,
      _UnavailablePreferences(),
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource?.name, defaultUserApiSourceName);
    expect(fetcher.urls, [Uri.parse(defaultUserApiSourceUrl)]);
  });

  test('keeps the default source while restoring the saved source', () async {
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
    expect(controller.state.sources.map((source) => source.name),
        [defaultUserApiSourceName, saved.name]);
    expect(fetcher.urls, [Uri.parse(defaultUserApiSourceUrl), saved.url]);
    expect(preferences.saved, isEmpty);
  });

  test('does not remove the built-in LX source', () async {
    final controller = await _sessionController(_Runner());
    final source = controller.state.sources.single;

    await controller.remove(source.id);

    expect(controller.state.sources, [source]);
    expect(controller.state.error?.message, '内置落雪音源不能移除');
  });

  test('a default source failure completes startup restore without a source',
      () async {
    final controller = UserApiDebugController(
      _Runner(),
      _FailingFetcher(),
      null,
      _Preferences(),
    );

    await controller.restorePersisted();

    expect(controller.state.activeSource, isNull);
    expect(controller.state.error?.message, '默认音源不可用');
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
}

final class _Preferences extends UserApiSourcePreferences {
  _Preferences([this.value]);

  final ({String name, Uri url})? value;
  final saved = <({String name, Uri url})>[];

  @override
  Future<({String name, Uri url})?> read() async => value;

  @override
  Future<void> save(String name, Uri url) async {
    saved.add((name: name, url: url));
  }

  @override
  Future<void> clear() async {}
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

final class _FailingFetcher extends UserApiScriptFetcher {
  _FailingFetcher() : super(Dio());

  @override
  Future<String> fetch(Uri uri) async => throw const AppFailure(
        code: AppFailureCode.noNetwork,
        message: '默认音源不可用',
      );
}

final class _Runner implements UserApiRunner {
  String? loadedScript;
  bool wasCleared = false;
  var resolveCount = 0;

  @override
  Future<void> clear() async {
    wasCleared = true;
    loadedScript = null;
  }

  @override
  Future<UserApiManifest> load(String script) async {
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
