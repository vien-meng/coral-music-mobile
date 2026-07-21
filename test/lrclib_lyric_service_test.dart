import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/lrclib_lyric_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers synced lyrics and falls back to plain lyrics', () {
    expect(
      parseLrcLibPayload({
        'syncedLyrics': '[00:01.00]同步歌词',
        'plainLyrics': '纯文本歌词',
      })?.lyric,
      '[00:01.00]同步歌词',
    );
    expect(
      parseLrcLibPayload({'plainLyrics': '纯文本歌词'})?.lyric,
      '纯文本歌词',
    );
    expect(parseLrcLibPayload({'plainLyrics': ''}), isNull);
  });

  test('selects the matching artist instead of the first search result', () {
    const track = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'kw',
      sourceTrackId: '1',
      title: '平凡之路',
      artist: '朴树',
    );
    final lyric = selectLrcLibSearchResult([
      {
        'trackName': '平凡之路',
        'artistName': '其他歌手',
        'syncedLyrics': '[00:01.00]错误候选',
      },
      {
        'trackName': '平凡之路',
        'artistName': '朴树',
        'plainLyrics': '正确候选',
      },
    ], track);

    expect(lyric?.lyric, '正确候选');
  });

  test('selects the closest title and artist candidate', () {
    const track = Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'mg',
      sourceTrackId: '1',
      title: '夜曲',
      artist: '周杰伦',
    );
    final lyric = selectLrcLibSearchResult([
      {
        'trackName': '夜曲',
        'artistName': '其他歌手',
        'syncedLyrics': '[00:01.00]错误歌词',
      },
      {
        'trackName': '夜曲版',
        'artistName': '周杰伦',
        'syncedLyrics': '[00:01.00]最接近歌词',
      },
    ], track);

    expect(lyric?.lyric, '[00:01.00]最接近歌词');
  });

  test('continues with keyword search when exact lookup fails', () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.path.endsWith('/api/get')) {
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
          ));
          return;
        }
        handler.resolve(Response(
          requestOptions: options,
          data: [
            {
              'trackName': '关键词歌曲',
              'artistName': '关键词歌手',
              'syncedLyrics': '[00:01.00]关键词歌词',
            },
          ],
        ));
      }));

    final lyric = await LrcLibLyricService(dio).resolve(const Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'tx',
      sourceTrackId: 'qq-song',
      title: '关键词歌曲',
      artist: '关键词歌手',
      duration: Duration(minutes: 3),
    ));

    expect(lyric?.lyric, '[00:01.00]关键词歌词');
  });

  test('retries with the title only when title and artist have no match',
      () async {
    final queries = <Map<String, dynamic>>[];
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        queries.add(Map<String, dynamic>.from(options.queryParameters));
        handler.resolve(Response(
          requestOptions: options,
          data: options.queryParameters.containsKey('artist_name')
              ? const []
              : [
                  {
                    'trackName': '仅歌名匹配',
                    'artistName': '不同写法歌手',
                    'plainLyrics': '标题检索歌词',
                  },
                ],
        ));
      }));

    final lyric = await LrcLibLyricService(dio).resolve(const Track(
      sourceKind: TrackSourceKind.online,
      sourceId: 'tx',
      sourceTrackId: 'qq-song',
      title: '仅歌名匹配',
      artist: '原歌手名',
    ));

    expect(lyric?.lyric, '标题检索歌词');
    expect(queries.last, isNot(contains('artist_name')));
  });
}
