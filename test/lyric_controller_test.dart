import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/user_api_runner.dart';
import 'package:coral_music_mobile/features/player/state/lyric_controller.dart';
import 'package:coral_music_mobile/features/player/state/player_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

final class _Runner implements UserApiRunner {
  var lyricRequests = 0;

  @override
  Future<void> clear() async {}

  @override
  Future<UserApiManifest> load(String script) async =>
      const UserApiManifest({'kw'});

  @override
  Future<LyricPayload?> resolveLyric(Track track) async {
    lyricRequests++;
    return const LyricPayload(lyric: '[00:01.00]不应请求');
  }

  @override
  Future<Uri> resolveMusicUrl(Track track, AudioQuality quality) async =>
      Uri.parse('https://example.com/audio.mp3');
}
