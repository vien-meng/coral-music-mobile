import 'dart:io';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/state/lyric_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps downloads and WebDAV tracks offline when lyrics are absent',
      () async {
    var fallbackRequests = 0;
    final container = ProviderContainer(
      overrides: [
        lyricFallbackProvider.overrideWithValue((_) async {
          fallbackRequests++;
          return null;
        }),
      ],
    );
    addTearDown(container.dispose);

    for (final source in [
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

    expect(fallbackRequests, 0);
  });

  test('prefers an LRC beside a local track before independent lookup',
      () async {
    final directory = await Directory.systemTemp.createTemp('coral-lyric-');
    addTearDown(() => directory.delete(recursive: true));
    final song = File('${directory.path}/song.flac');
    await song.writeAsBytes(const []);
    await File('${directory.path}/song.lrc').writeAsString('[00:01.00]本地歌词');
    var fallbackRequests = 0;
    final container = ProviderContainer(
      overrides: [
        lyricFallbackProvider.overrideWithValue((_) async {
          fallbackRequests++;
          return null;
        }),
      ],
    );
    addTearDown(container.dispose);

    final lyric = await container.read(lyricProvider(Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'device',
      sourceTrackId: song.path,
      title: '歌曲',
      artist: '歌手',
      localUri: song.uri,
    )).future);

    expect(lyric?.lyric, '[00:01.00]本地歌词');
    expect(fallbackRequests, 0);
  });

  test('searches an independent lyric service for a local track without LRC',
      () async {
    var fallbackRequests = 0;
    final container = ProviderContainer(
      overrides: [
        lyricFallbackProvider.overrideWithValue((track) async {
          fallbackRequests++;
          expect(track.title, '本地歌曲');
          expect(track.artist, '本地歌手');
          return const LyricPayload(lyric: '[00:01.00]搜索到的歌词');
        }),
      ],
    );
    addTearDown(container.dispose);

    final lyric = await container.read(lyricProvider(const Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'device',
      sourceTrackId: 'local-song',
      title: '本地歌曲',
      artist: '本地歌手',
    )).future);

    expect(lyric?.lyric, '[00:01.00]搜索到的歌词');
    expect(fallbackRequests, 1);
  });

  test('uses the same independent lyric service for every online source',
      () async {
    final container = ProviderContainer(
      overrides: [
        lyricFallbackProvider.overrideWithValue(
          (_) async => const LyricPayload(lyric: '[00:01.00]独立歌词'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final lyric = await container.read(lyricProvider(const Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: 'fallback',
      title: '在线歌曲',
      artist: '测试歌手',
    )).future);

    expect(lyric?.lyric, '[00:01.00]独立歌词');
  });

  test('keeps the last successful lyric when an independent refresh fails',
      () async {
    var requests = 0;
    final container = ProviderContainer(
      overrides: [
        lyricFallbackProvider.overrideWithValue((_) async {
          requests++;
          return requests == 1
              ? const LyricPayload(lyric: '[00:01.00]缓存歌词')
              : null;
        }),
      ],
    );
    addTearDown(container.dispose);
    const track = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'tx',
      sourceTrackId: 'cached',
      title: '在线歌曲',
      artist: '测试歌手',
    );

    final first = await container.read(lyricProvider(track).future);
    final second = await container.refresh(lyricProvider(track).future);

    expect(second?.lyric, first?.lyric);
    expect(requests, 2);
  });
}
