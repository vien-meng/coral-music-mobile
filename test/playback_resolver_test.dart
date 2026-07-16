import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/playback_resolver.dart';
import 'package:coral_music_mobile/features/player/data/user_api_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = Track(
    sourceKind: TrackSourceKind.online,
    sourceId: 'kw',
    sourceTrackId: '1',
    title: '测试歌曲',
    artist: '测试歌手',
  );

  test('caches a resolved URL and refreshes it when requested', () async {
    final runner = _Runner();
    final resolver = PlaybackResolver(runner);

    await resolver.resolve(track);
    await resolver.resolve(track);
    expect(runner.resolveCount, 1);

    await resolver.resolve(track, forceRefresh: true);
    expect(runner.resolveCount, 2);
  });

  test('uses non-online URIs without invoking User API', () async {
    final runner = _Runner();
    final resolver = PlaybackResolver(runner);

    for (final source in [
      TrackSourceKind.local,
      TrackSourceKind.download,
      TrackSourceKind.webdav,
    ]) {
      final uri = await resolver.resolve(
        Track(
          sourceKind: source,
          sourceId: source.name,
          sourceTrackId: '1',
          title: '来源歌曲',
          artist: '测试歌手',
          localUri: Uri.parse('https://example.com/${source.name}.mp3'),
        ),
      );
      expect(uri.host, 'example.com');
    }

    expect(runner.resolveCount, 0);
  });
}

final class _Runner implements UserApiRunner {
  var resolveCount = 0;

  @override
  Future<void> clear() async {}

  @override
  Future<LyricPayload?> resolveLyric(Track track) async => null;

  @override
  Future<UserApiManifest> load(String script) async =>
      const UserApiManifest({'kw'});

  @override
  Future<Uri> resolveMusicUrl(Track track, AudioQuality quality) async {
    resolveCount++;
    return Uri.parse('https://example.com/$resolveCount.mp3');
  }
}
