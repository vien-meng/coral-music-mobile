import 'package:coral_music_mobile/core/app_failure.dart';
import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/user_api_runner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects a blank script before invoking the native runtime', () async {
    const channel = MethodChannel('coral_music/user_api');
    var invoked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      invoked = true;
      return <String, Object?>{};
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await expectLater(
      MethodChannelUserApiRunner().load(' \n\t '),
      throwsA(isA<AppFailure>()),
    );
    expect(invoked, isFalse);
  });

  test('preserves the actual quality returned by an enabled User API',
      () async {
    const channel = MethodChannel('coral_music/user_api');
    Map<Object?, Object?>? request;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'load') {
        return <String, Object?>{
          'musicUrlSources': ['kg'],
          'musicUrlQualities': {
            'kg': ['128k', 'flac', 'hires', 'master'],
          },
        };
      }
      if (call.method == 'resolveMusicUrl') {
        request = call.arguments as Map<Object?, Object?>;
        return <String, Object?>{
          'url': 'http://media.example.com/a.mp3',
          'type': '320k',
        };
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final runner = MethodChannelUserApiRunner();
    final manifest = await runner.load('source');
    expect(manifest.musicUrlQualities['kg'], {
      AudioQuality.standard128k,
      AudioQuality.flac,
      AudioQuality.hires,
      AudioQuality.master,
    });
    final playbackUrl = await runner.resolveMusicUrl(
      const Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'kg',
        sourceTrackId: '1',
        title: '测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        duration: Duration(minutes: 4, seconds: 3),
        extra: {
          'albumId': '2',
          'hash': '128-hash',
          'qualityMeta': {
            '128k': {'hash': '128-hash', 'size': 3000000},
          },
        },
      ),
      AudioQuality.standard128k,
    );

    expect(playbackUrl.uri.scheme, 'http');
    expect(playbackUrl.quality, AudioQuality.high320k);
    final musicInfo = request!['musicInfo']! as Map<Object?, Object?>;
    final meta = musicInfo['meta']! as Map<Object?, Object?>;
    expect(musicInfo['id'], '1');
    expect(musicInfo['interval'], '04:03');
    expect(meta['songId'], '1');
    expect(meta['albumId'], '2');
    expect((meta['_qualitys']! as Map)['128k'], {
      'hash': '128-hash',
      'size': 3000000,
    });
  });

  test('keeps QQ and Migu desktop fields at the User API boundary', () async {
    const channel = MethodChannel('coral_music/user_api');
    final requests = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'load') {
        return <String, Object?>{
          'musicUrlSources': ['tx', 'mg'],
        };
      }
      if (call.method == 'resolveMusicUrl') {
        requests.add(call.arguments as Map<Object?, Object?>);
        return 'https://media.example.com/audio.mp3';
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final runner = MethodChannelUserApiRunner();
    await runner.load('source');
    await runner.resolveMusicUrl(
      const Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'tx',
        sourceTrackId: 'qq-mid',
        title: 'QQ 歌曲',
        artist: 'QQ 歌手',
        availableQualities: [AudioQuality.flac, AudioQuality.high320k],
        extra: {
          'songId': 12,
          'albumMid': 'album-mid',
          'mediaMid': 'media-mid',
          'qualityMeta': {
            'flac': {'size': 30000000},
            '320k': {'size': 8000000},
          },
        },
      ),
      AudioQuality.flac,
    );
    await runner.resolveMusicUrl(
      const Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'mg',
        sourceTrackId: 'migu-song',
        title: '咪咕歌曲',
        artist: '咪咕歌手',
        availableQualities: [AudioQuality.flac],
        extra: {
          'copyrightId': 'copyright-id',
          'qualityMeta': {
            'flac': {'size': 30000000},
          },
          'lrcUrl': 'https://example.com/song.lrc',
          'mrcUrl': 'https://example.com/song.mrc',
          'trcUrl': 'https://example.com/song.trc',
        },
      ),
      AudioQuality.standard128k,
    );

    final qq = requests[0]['musicInfo']! as Map<Object?, Object?>;
    expect(qq['strMediaMid'], 'media-mid');
    expect(qq['songId'], 12);
    expect(qq['types'], [
      {'type': 'flac', 'size': 30000000},
      {'type': '320k', 'size': 8000000},
    ]);
    final migu = requests[1]['musicInfo']! as Map<Object?, Object?>;
    expect(migu['songmid'], 'migu-song');
    expect(migu['copyrightId'], 'copyright-id');
    expect(migu['types'], [
      {'type': 'flac', 'size': 30000000},
    ]);
    expect(migu['mrcUrl'], 'https://example.com/song.mrc');
    expect(migu['trcUrl'], 'https://example.com/song.trc');
  });
}
