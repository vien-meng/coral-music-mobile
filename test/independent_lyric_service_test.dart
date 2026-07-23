import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/independent_lyric_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers title and artist lookup before the source endpoint', () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.host == 'lrclib.net') {
            handler.resolve(Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {'syncedLyrics': '[00:01.00]独立检索歌词'},
            ));
          } else {
            handler.resolve(Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {'code': '1'},
            ));
          }
        },
      ));

    final lyric = await IndependentLyricService(dio).resolve(const Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'tx',
      sourceTrackId: 'qq-mid',
      title: '独立检索歌曲',
      artist: '独立检索歌手',
      duration: Duration(minutes: 3),
    ));

    expect(lyric?.lyric, '[00:01.00]独立检索歌词');
  });

  test('loads QQ lyrics without a User API script', () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response<String>(
          requestOptions: options,
          statusCode: 200,
          data: 'MusicJsonCallback({"code":"0","lyric":"[00:01.00]歌词"})',
        )),
      ));

    final lyric = await IndependentLyricService(dio).resolve(const Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'tx',
      sourceTrackId: 'qq-mid',
      title: 'QQ 歌曲',
      artist: 'QQ 歌手',
    ));

    expect(lyric?.lyric, '[00:01.00]歌词');
  });
}
