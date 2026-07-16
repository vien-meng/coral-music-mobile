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

  test('accepts a legacy HTTP playback URL from an enabled User API', () async {
    const channel = MethodChannel('coral_music/user_api');
    Map<Object?, Object?>? request;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'load') {
        return <String, Object?>{
          'musicUrlSources': ['kw']
        };
      }
      if (call.method == 'resolveMusicUrl') {
        request = call.arguments as Map<Object?, Object?>;
        return 'http://media.example.com/a.mp3';
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final runner = MethodChannelUserApiRunner();
    await runner.load('source');
    final uri = await runner.resolveMusicUrl(
      const Track(
        sourceKind: TrackSourceKind.online,
        sourceId: 'kw',
        sourceTrackId: '1',
        title: '测试歌曲',
        artist: '测试歌手',
        album: '测试专辑',
        duration: Duration(minutes: 4, seconds: 3),
        extra: {'albumId': '2'},
      ),
      AudioQuality.standard128k,
    );

    expect(uri.scheme, 'http');
    final musicInfo = request!['musicInfo']! as Map<Object?, Object?>;
    final meta = musicInfo['meta']! as Map<Object?, Object?>;
    expect(musicInfo['id'], '1');
    expect(musicInfo['interval'], '04:03');
    expect(meta['songId'], '1');
    expect(meta['albumId'], '2');
  });
}
