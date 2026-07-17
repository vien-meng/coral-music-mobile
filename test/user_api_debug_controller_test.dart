import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/user_api_runner.dart';
import 'package:coral_music_mobile/features/player/state/user_api_debug_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports, activates and removes session-only User API sources',
      () async {
    final runner = _Runner();
    final controller = UserApiDebugController(runner);

    await controller.importScript('酷我音源', 'kw-script');
    await controller.importScript('QQ 音源', 'qq-script');

    expect(controller.state.sources, hasLength(2));
    expect(controller.state.activeSource?.name, 'QQ 音源');
    expect(controller.state.activeSource?.musicUrlSources, {'qq'});

    final kuwoId = controller.state.sources.first.id;
    await controller.activate(kuwoId);
    expect(controller.state.activeSource?.name, '酷我音源');
    expect(runner.loadedScript, 'kw-script');

    await controller.remove(kuwoId);
    expect(controller.state.activeSource, isNull);
    expect(runner.wasCleared, isTrue);
  });

  test('uses public script header details instead of a generated source name',
      () async {
    final controller = UserApiDebugController(_Runner());

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
}

final class _Runner implements UserApiRunner {
  String? loadedScript;
  bool wasCleared = false;

  @override
  Future<void> clear() async {
    wasCleared = true;
    loadedScript = null;
  }

  @override
  Future<UserApiManifest> load(String script) async {
    loadedScript = script;
    return UserApiManifest(
      {script.startsWith('kw') ? 'kw' : 'qq'},
      lyricSources: {script.startsWith('kw') ? 'kw' : 'qq'},
    );
  }

  @override
  Future<LyricPayload?> resolveLyric(Track track) async => null;

  @override
  Future<Uri> resolveMusicUrl(Track track, AudioQuality quality) async =>
      Uri.parse('https://example.com/audio.mp3');
}
