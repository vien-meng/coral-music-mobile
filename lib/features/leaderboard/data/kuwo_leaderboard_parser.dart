import '../../../core/app_failure.dart';
import '../../../domain/music.dart';

final class KuwoLeaderboardParser {
  static PageResult<Track> parse(
    Map<String, Object?> response, {
    required int page,
    int pageSize = 100,
  }) {
    final data = response['data'];
    if (response['code'] != 200 || data is! Map<String, Object?>) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '榜单数据格式异常',
      );
    }
    final rawList = data['musiclist'];
    if (rawList is! List<Object?>) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '榜单歌曲数据缺失',
      );
    }

    final tracks = <Track>[];
    final ids = <String>{};
    for (final value in rawList) {
      if (value is! Map<String, Object?>) continue;
      final sourceTrackId = '${value['id'] ?? ''}'.trim();
      final title = decodeText('${value['name'] ?? ''}').trim();
      if (sourceTrackId.isEmpty || title.isEmpty || !ids.add(sourceTrackId)) {
        continue;
      }
      final durationSeconds = int.tryParse('${value['duration'] ?? ''}');
      final cover = Uri.tryParse('${value['pic'] ?? ''}');
      tracks.add(
        Track(
          sourceKind: TrackSourceKind.online,
          sourceId: OnlineSource.kuwo.id,
          sourceTrackId: sourceTrackId,
          title: title,
          artist: decodeText('${value['artist'] ?? ''}')
              .replaceAll('&', '、')
              .trim(),
          album: decodeText('${value['album'] ?? ''}').trim(),
          duration: durationSeconds == null
              ? null
              : Duration(seconds: durationSeconds),
          coverUri: cover?.hasScheme == true ? cover : null,
          availableQualities: parseQualities('${value['n_minfo'] ?? ''}'),
          extra: {'albumId': value['albumId']},
        ),
      );
    }

    return PageResult(
      items: tracks,
      page: page,
      pageSize: pageSize,
      total: int.tryParse('${data['total'] ?? ''}') ?? tracks.length,
    );
  }

  static List<AudioQuality> parseQualities(String raw) {
    final qualities = <AudioQuality>{};
    for (final match in RegExp(r'bitrate:(\d+)').allMatches(raw)) {
      switch (match.group(1)) {
        case '4000':
          qualities.add(AudioQuality.flac24bit);
        case '2000':
          qualities.add(AudioQuality.flac);
        case '320':
          qualities.add(AudioQuality.high320k);
        case '192':
          qualities.add(AudioQuality.high192k);
        case '128':
          qualities.add(AudioQuality.standard128k);
      }
    }
    return AudioQuality.values
        .where(qualities.contains)
        .toList(growable: false);
  }

  static String decodeText(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
