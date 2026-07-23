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
      if (value is! Map) continue;
      final item = Map<String, Object?>.from(value);
      final sourceTrackId = _id(item);
      final title = KuwoLeaderboardParser.decodeText(
        '${item['SONGNAME'] ?? item['NAME'] ?? ''}',
      ).trim();
      if (sourceTrackId.isEmpty || title.isEmpty || !ids.add(sourceTrackId)) {
        continue;
      }
      final duration = int.tryParse('${item['DURATION'] ?? ''}');
      tracks.add(
        Track(
          sourceKind: TrackSourceKind.online,
          sourceId: OnlineSource.kuwo.id,
          sourceTrackId: sourceTrackId,
          title: title,
          artist: KuwoLeaderboardParser.decodeText('${item['ARTIST'] ?? ''}')
              .replaceAll('&', '、')
              .trim(),
          album:
              KuwoLeaderboardParser.decodeText('${item['ALBUM'] ?? ''}').trim(),
          duration: duration == null ? null : Duration(seconds: duration),
          coverUri: _cover(item),
          availableQualities: KuwoLeaderboardParser.parseQualities(
            '${item['N_MINFO'] ?? item['MINFO'] ?? ''}',
          ),
          extra: {'albumId': item['ALBUMID']},
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

  static Uri? _cover(Map<String, Object?> item) {
    final direct = _httpsUri('${item['pic'] ?? ''}') ??
        _httpsUri('${item['albumpic'] ?? ''}') ??
        _httpsUri('${item['albumPic'] ?? ''}');
    if (direct != null) return direct;
    final parts = '${item['web_albumpic_short'] ?? ''}'.trim().split('/');
    if (parts.length < 2 || parts.skip(1).any((part) => part.isEmpty)) {
      return null;
    }
    return Uri.https(
      'img3.kuwo.cn',
      '/star/albumcover/500/${parts.skip(1).join('/')}',
    );
  }

  static Uri? _httpsUri(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return null;
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }
}
