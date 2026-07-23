import '../../../core/app_failure.dart';
import '../../../core/response_json.dart';
import '../../../domain/music.dart';

final class KugouSearchParser {
  static PageResult<Track> parse(
    Object? response, {
    required int page,
    int pageSize = 30,
  }) {
    final responseMap = decodeJsonMap(response);
    final data = responseMap['data'] as Map?;
    final rawList = data?['lists'];
    if (responseMap['error_code'] != 0 || data == null || rawList is! List) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '酷狗音乐搜索数据格式异常',
      );
    }

    final tracks = <Track>[];
    final ids = <String>{};
    for (final value in rawList.whereType<Map>()) {
      _appendTrack(tracks, ids, value);
      final groups = value['Grp'];
      if (groups is List) {
        for (final child in groups.whereType<Map>()) {
          _appendTrack(tracks, ids, child);
        }
      }
    }
    return PageResult(
      items: tracks,
      page: page,
      pageSize: pageSize,
      total: int.tryParse('${data['total'] ?? ''}') ?? tracks.length,
    );
  }

  static void _appendTrack(
    List<Track> tracks,
    Set<String> ids,
    Map value,
  ) {
    final audioId = '${value['Audioid'] ?? ''}'.trim();
    final hash = '${value['FileHash'] ?? ''}'.trim();
    final title = '${value['SongName'] ?? ''}'.trim();
    final id = audioId.isNotEmpty ? audioId : hash;
    if (id.isEmpty || title.isEmpty || !ids.add('$id:$hash')) return;

    final qualityMeta = <String, Map<String, Object?>>{};
    void addQuality(String name, String hashKey, String sizeKey) {
      final qualityHash = '${value[hashKey] ?? ''}'.trim();
      final size = int.tryParse('${value[sizeKey] ?? ''}') ?? 0;
      if (qualityHash.isNotEmpty && size > 0) {
        qualityMeta[name] = {'hash': qualityHash, 'size': size};
      }
    }

    addQuality('128k', 'FileHash', 'FileSize');
    addQuality('320k', 'HQFileHash', 'HQFileSize');
    addQuality('flac', 'SQFileHash', 'SQFileSize');
    addQuality(
      'flac24bit',
      'ResFileHash',
      'ResFileSize',
    );
    final qualities = <AudioQuality>[
      if (qualityMeta.containsKey('flac24bit')) AudioQuality.flac24bit,
      if (qualityMeta.containsKey('flac')) AudioQuality.flac,
      if (qualityMeta.containsKey('320k')) AudioQuality.high320k,
      if (qualityMeta.containsKey('128k')) AudioQuality.standard128k,
    ];
    tracks.add(
      Track(
        sourceKind: TrackSourceKind.online,
        sourceId: OnlineSource.kugou.id,
        sourceTrackId: id,
        title: title,
        artist: _artists(value['Singers']),
        album: '${value['AlbumName'] ?? ''}'.trim(),
        duration: _duration(value['Duration']),
        coverUri: _cover(value['Image'] ?? value['AlbumImage']),
        availableQualities: qualities,
        extra: {
          'songId': audioId,
          'albumId': value['AlbumID'],
          'hash': hash,
          'qualityMeta': qualityMeta,
        },
      ),
    );
  }

  static String _artists(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => '${item['name'] ?? item['Name'] ?? ''}'.trim())
          .where((name) => name.isNotEmpty)
          .join('、');
    }
    if (raw is Map) return '${raw['name'] ?? raw['Name'] ?? ''}'.trim();
    return '$raw'.trim();
  }

  static Duration? _duration(Object? value) {
    final seconds = int.tryParse('$value');
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }

  static Uri? _cover(Object? value) {
    final raw = '$value'.trim().replaceAll('{size}', '480');
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return null;
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }
}
