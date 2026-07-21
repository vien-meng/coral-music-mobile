import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/song_list/data/kuwo_playlist_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves non-8 digest nodes before loading Kuwo playlist detail',
      () async {
    final requests = <Uri>[];
    final service = KuwoPlaylistService(_fakeDio(requests));

    await service.getPlaylistDetail(const OnlinePlaylist(
      id: 'digest-5__123',
      source: OnlineSource.kuwo,
      name: '测试歌单',
    ));

    expect(requests, hasLength(2));
    expect(requests.first.host, 'qukudata.kuwo.cn');
    expect(requests.first.queryParameters['node'], '123');
    expect(requests.last.queryParameters['pid'], '456');
  });

  test('loads digest-8 Kuwo playlist detail directly', () async {
    final requests = <Uri>[];
    final service = KuwoPlaylistService(_fakeDio(requests));

    await service.getPlaylistDetail(const OnlinePlaylist(
      id: 'digest-8__123',
      source: OnlineSource.kuwo,
      name: '测试歌单',
    ));

    expect(requests, hasLength(1));
    expect(requests.single.host, 'nplserver.kuwo.cn');
    expect(requests.single.queryParameters['pid'], '123');
  });
}

Dio _fakeDio(List<Uri> requests) => Dio()
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      requests.add(options.uri);
      handler.resolve(Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: options.uri.host == 'qukudata.kuwo.cn'
            ? {
                'child': [
                  {'sourceid': 456},
                ],
              }
            : {
                'result': 'ok',
                'musiclist': <Object?>[],
                'title': '测试歌单',
                'total': 0,
              },
      ));
    },
  ));
