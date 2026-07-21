import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/independent_lyric_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
