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
