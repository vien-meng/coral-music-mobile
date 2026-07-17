import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/user_api_runner.dart';
import 'package:coral_music_mobile/features/player/state/lyric_controller.dart';
import 'package:coral_music_mobile/features/player/state/player_controller.dart';
import 'package:coral_music_mobile/features/player/state/user_api_debug_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('never queries User API lyrics for non-online tracks', () async {
    final runner = _Runner();
    final container = ProviderContainer(
      overrides: [userApiRunnerProvider.overrideWithValue(runner)],
    );
    addTearDown(container.dispose);

    for (final source in [
      TrackSourceKind.local,
      TrackSourceKind.download,
      TrackSourceKind.webdav,
    ]) {
      final lyric = await container.read(
        lyricProvider(
          Track(
            sourceKind: source,
            sourceId: source.name,
            sourceTrackId: '1',
            title: '离线歌曲',
            artist: '测试歌手',
          ),
        ).future,
      );
      expect(lyric, isNull);
    }

    expect(runner.lyricRequests, 0);
  });

  test('falls back to User API when the native Kuwo lyric channel is absent',
      () async {
    final runner = _Runner();
    final container = ProviderContainer(
      overrides: [userApiRunnerProvider.overrideWithValue(runner)],
    );
    addTearDown(container.dispose);

    final lyric = await container.read(
      lyricProvider(const Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'kw',
        sourceTrackId: '1',
        title: '在线歌曲',
        artist: '测试歌手',
      )).future,
    );

    expect(runner.lyricRequests, 1);
    expect(lyric?.lyric, '[00:01.00]不应请求');
  });

  test('reloads the current track lyric after the active source changes',
      () async {
    final runner = _Runner();
    final container = ProviderContainer(
      overrides: [userApiRunnerProvider.overrideWithValue(runner)],
    );
    addTearDown(container.dispose);
    const track = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: 'source-change',
      title: '在线歌曲',
      artist: '测试歌手',
    );
    final source = container.read(userApiDebugProvider.notifier);

    await source.importScript('版本一', 'kw-v1');
    final first = await container.read(lyricProvider(track).future);
    await source.importScript('版本二', 'kw-v2');
    final second = await container.read(lyricProvider(track).future);

    expect(first?.lyric, '[00:01.00]kw-v1');
    expect(second?.lyric, '[00:01.00]kw-v2');
    expect(runner.lyricRequests, 2);
  });
}

final class _Runner implements UserApiRunner {
  var lyricRequests = 0;
  String? loadedScript;

  @override
  Future<void> clear() async {}

  @override
  Future<UserApiManifest> load(String script) async {
    loadedScript = script;
    return const UserApiManifest({'kw'});
  }

  @override
  Future<LyricPayload?> resolveLyric(Track track) async {
    lyricRequests++;
    return LyricPayload(lyric: '[00:01.00]${loadedScript ?? '不应请求'}');
  }

  @override
  Future<ResolvedPlaybackUrl> resolveMusicUrl(
    Track track,
    AudioQuality quality,
  ) async =>
      ResolvedPlaybackUrl(Uri.parse('https://example.com/audio.mp3'));
}
