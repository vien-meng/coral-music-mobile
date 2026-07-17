import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../../leaderboard/data/kuwo_leaderboard_parser.dart';

final class KuwoSearchParser {
  static PageResult<Track> parse(
    Map<String, Object?> response, {
    required int page,
    int pageSize = 30,
  }) {
    final rawList = response['abslist'];
    if (rawList is! List<Object?>) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '搜索歌曲数据缺失',
      );
    }

    final tracks = <Track>[];
    final ids = <String>{};
    for (final value in rawList) {
      if (value is! Map<String, Object?>) continue;
      final sourceTrackId = _id(value);
      final title = KuwoLeaderboardParser.decodeText(
        '${value['SONGNAME'] ?? value['NAME'] ?? ''}',
      ).trim();
      if (sourceTrackId.isEmpty || title.isEmpty || !ids.add(sourceTrackId)) {
        continue;
      }
      final duration = int.tryParse('${value['DURATION'] ?? ''}');
      tracks.add(
        Track(
          sourceKind: TrackSourceKind.online,
          sourceId: OnlineSource.kuwo.id,
          sourceTrackId: sourceTrackId,
          title: title,
          artist: KuwoLeaderboardParser.decodeText('${value['ARTIST'] ?? ''}')
              .replaceAll('&', '、')
              .trim(),
          album: KuwoLeaderboardParser.decodeText('${value['ALBUM'] ?? ''}')
              .trim(),
          duration: duration == null ? null : Duration(seconds: duration),
          coverUri: _cover(value['web_albumpic_short']),
          availableQualities: KuwoLeaderboardParser.parseQualities(
            '${value['N_MINFO'] ?? value['MINFO'] ?? ''}',
          ),
          extra: {'albumId': value['ALBUMID']},
        ),
      );
    }

    return PageResult(
      items: tracks,
      page: page,
      pageSize: pageSize,
      total: int.tryParse('${response['TOTAL'] ?? ''}') ?? tracks.length,
    );
  }

  static String _id(Map<String, Object?> value) {
    final musicRid = '${value['MUSICRID'] ?? ''}'.trim();
    if (musicRid.startsWith('MUSIC_')) {
      return musicRid.substring('MUSIC_'.length);
    }
    return musicRid.isNotEmpty
        ? musicRid
        : '${value['DC_TARGETID'] ?? ''}'.trim();
  }

  static Uri? _cover(Object? value) {
    final parts = '$value'.trim().split('/');
    if (parts.length < 2 || parts.skip(1).any((part) => part.isEmpty)) {
      return null;
    }
    return Uri.https(
      'img3.kuwo.cn',
      '/star/albumcover/500/${parts.skip(1).join('/')}',
    );
  }
}
