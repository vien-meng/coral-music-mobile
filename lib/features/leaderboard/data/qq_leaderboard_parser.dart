import '../../../core/app_failure.dart';
import '../../../domain/music.dart';

final class QqLeaderboardParser {
  static PageResult<Track> parse(Map<String, Object?> response) {
    final toplist = response['toplist'];
    if (response['code'] != 0 || toplist is! Map<String, Object?>) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐榜单数据格式异常',
      );
    }
    final data = toplist['data'];
    final rawList = data is Map<String, Object?> ? data['songInfoList'] : null;
    if (rawList is! List<Object?>) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: 'QQ 音乐榜单歌曲数据缺失',
      );
    }

    final tracks = <Track>[];
    final ids = <String>{};
    for (final value in rawList) {
      if (value is! Map<String, Object?>) continue;
      final sourceTrackId = '${value['mid'] ?? value['id'] ?? ''}'.trim();
      final title = '${value['title'] ?? value['name'] ?? ''}'.trim();
      if (sourceTrackId.isEmpty || title.isEmpty || !ids.add(sourceTrackId)) {
        continue;
      }
      final album = value['album'];
      final albumInfo =
          album is Map<String, Object?> ? album : const <String, Object?>{};
      final singers = value['singer'];
      final singerList = singers is List<Object?> ? singers : const <Object?>[];
      final singerNames = singerList
          .whereType<Map<String, Object?>>()
          .map((item) => '${item['name'] ?? ''}'.trim())
          .where((name) => name.isNotEmpty)
          .join('、');
      final albumMid = '${albumInfo['mid'] ?? ''}'.trim();
      final singerMid = singerList
          .whereType<Map<String, Object?>>()
          .map((item) => '${item['mid'] ?? ''}'.trim())
          .firstWhere((mid) => mid.isNotEmpty, orElse: () => '');
      final coverId = albumMid.isNotEmpty
          ? 'T002$albumMid'
          : singerMid.isEmpty
              ? ''
              : 'T001$singerMid';
      tracks.add(
        Track(
          sourceKind: TrackSourceKind.online,
          sourceId: OnlineSource.qq.id,
          sourceTrackId: sourceTrackId,
          title: title,
          artist: singerNames,
          album: '${albumInfo['name'] ?? ''}'.trim(),
          duration: _seconds(value['interval']),
          coverUri: coverId.isEmpty
              ? null
              : Uri.parse(
                  'https://y.gtimg.cn/music/photo_new/${coverId}R500x500M000.jpg'),
          availableQualities: _qualities(value['file']),
          extra: {
            'songId': value['id'],
            'albumMid': albumMid,
            'mediaMid': (value['file'] as Map?)?['media_mid'],
          },
        ),
      );
    }
    return PageResult(
      items: tracks,
      page: 1,
      pageSize: tracks.length,
      total: tracks.length,
    );
  }

  static Duration? _seconds(Object? value) {
    final seconds = int.tryParse('$value');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static List<AudioQuality> _qualities(Object? value) {
    if (value is! Map) return const [];
    final qualities = <AudioQuality>{};
    if (_positive(value['size_hires'])) qualities.add(AudioQuality.flac24bit);
    if (_positive(value['size_flac'])) qualities.add(AudioQuality.flac);
    if (_positive(value['size_320mp3'])) qualities.add(AudioQuality.high320k);
    if (_positive(value['size_128mp3'])) {
      qualities.add(AudioQuality.standard128k);
    }
    return AudioQuality.values
        .where(qualities.contains)
        .toList(growable: false);
  }

  static bool _positive(Object? value) => (int.tryParse('$value') ?? 0) > 0;
}
