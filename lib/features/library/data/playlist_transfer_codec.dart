import 'dart:convert';

import '../../../domain/music.dart';

final class ImportedPlaylist {
  const ImportedPlaylist({required this.name, required this.tracks});

  final String name;
  final List<Track> tracks;
}

/// Desktop-compatible single-playlist JSON codec.
final class PlaylistTransferCodec {
  static String encode(UserPlaylist playlist, Iterable<Track> tracks) =>
      const JsonEncoder.withIndent('  ').convert({
        'type': 'playListPart_v2',
        'data': {
          'id': playlist.id,
          'name': playlist.name,
          'list': tracks.map(encodeTrack).toList(growable: false),
        },
      });

  static ImportedPlaylist decode(String raw) {
    final root = jsonDecode(raw);
    if (root is! Map) throw const FormatException('列表文件不是 JSON 对象');
    final type = root['type'];
    if (type != 'playListPart' && type != 'playListPart_v2') {
      throw const FormatException('不支持的列表文件');
    }
    final data = root['data'];
    if (data is! Map) throw const FormatException('列表文件内容不完整');
    final name = '${data['name'] ?? ''}'.trim();
    final list = data['list'];
    if (name.isEmpty || list is! List) {
      throw const FormatException('列表文件内容不完整');
    }
    final ids = <String>{};
    final tracks = <Track>[];
    for (final value in list) {
      if (value is! Map) continue;
      final track = decodeTrack(value);
      if (track != null && ids.add(track.id)) tracks.add(track);
    }
    return ImportedPlaylist(name: name, tracks: tracks);
  }

  static Map<String, Object?> encodeTrack(Track track) {
    final source = switch (track.sourceKind) {
      TrackSourceKind.online => track.sourceId,
      TrackSourceKind.webdav => 'webdav',
      TrackSourceKind.local || TrackSourceKind.download => 'local',
    };
    final songId = track.extra['songId'] ?? track.sourceTrackId;
    final meta = <String, Object?>{
      'songId': '$songId',
      'albumName': track.album ?? '',
      'picUrl': track.coverUri?.toString(),
      if (track.sourceKind == TrackSourceKind.online) ...{
        'qualitys': track.availableQualities
            .map((quality) => {'type': _desktopQuality(quality), 'size': null})
            .toList(growable: false),
        '_qualitys': {
          for (final quality in track.availableQualities)
            _desktopQuality(quality): {'size': null},
        },
        if (track.extra['albumId'] != null) 'albumId': track.extra['albumId'],
        if (track.sourceId == 'kg' && track.extra['hash'] != null)
          'hash': track.extra['hash'],
        if (track.sourceId == 'tx') ...{
          if (track.extra['mediaMid'] != null)
            'strMediaMid': track.extra['mediaMid'],
          if (track.extra['songId'] != null) 'id': track.extra['songId'],
        },
        if (track.sourceId == 'mg' && track.extra['copyrightId'] != null)
          'copyrightId': track.extra['copyrightId'],
      },
      if (track.sourceKind == TrackSourceKind.webdav) ...{
        'accountId': track.sourceId,
        'href': track.localUri?.toString() ?? track.sourceTrackId,
        'ext': _extension(track.localUri?.path ?? track.sourceTrackId),
      },
      if (track.sourceKind == TrackSourceKind.local ||
          track.sourceKind == TrackSourceKind.download) ...{
        'filePath': _filePath(track.localUri, track.sourceTrackId),
        'ext': _extension(track.localUri?.path ?? track.sourceTrackId),
        if (track.extra['cueStartMs'] != null)
          'trackStartMs': track.extra['cueStartMs'],
        if (track.extra['cueEndMs'] != null)
          'trackEndMs': track.extra['cueEndMs'],
      },
    };
    return {
      'id': '${source}_${track.sourceTrackId}',
      'name': track.title,
      'singer': track.artist,
      'source': source,
      'interval': _formatDuration(track.duration),
      'meta': meta,
    };
  }

  static Track? decodeTrack(Map value) {
    final source = '${value['source'] ?? ''}'.trim();
    final title = '${value['name'] ?? ''}'.trim();
    final meta = value['meta'];
    if (title.isEmpty || meta is! Map) return null;
    final songId = '${meta['songId'] ?? ''}'.trim();
    final baseExtra = <String, Object?>{
      if (meta['albumId'] != null) 'albumId': meta['albumId'],
      if (meta['hash'] != null) 'hash': meta['hash'],
      if (meta['strMediaMid'] != null) 'mediaMid': meta['strMediaMid'],
      if (meta['id'] != null) 'songId': meta['id'],
      if (meta['copyrightId'] != null) 'copyrightId': meta['copyrightId'],
    };
    final common = (
      title: title,
      artist: '${value['singer'] ?? ''}',
      album: '${meta['albumName'] ?? ''}',
      duration: _parseDuration(value['interval']),
      cover: Uri.tryParse('${meta['picUrl'] ?? ''}'),
    );
    if (source == 'local') {
      final path = '${meta['filePath'] ?? songId}'.trim();
      if (path.isEmpty) return null;
      return Track(
        sourceKind: TrackSourceKind.local,
        sourceId: 'local',
        sourceTrackId: path,
        title: common.title,
        artist: common.artist,
        album: common.album.isEmpty ? null : common.album,
        duration: common.duration,
        coverUri: common.cover?.hasScheme == true ? common.cover : null,
        localUri: Uri.file(path),
        availableQualities: const [],
        extra: {
          if (meta['trackStartMs'] is num) 'cueStartMs': meta['trackStartMs'],
          if (meta['trackEndMs'] is num) 'cueEndMs': meta['trackEndMs'],
        },
      );
    }
    if (source == 'webdav') {
      final href = '${meta['href'] ?? songId}'.trim();
      if (href.isEmpty) return null;
      return Track(
        sourceKind: TrackSourceKind.webdav,
        sourceId: '${meta['accountId'] ?? ''}',
        sourceTrackId: href,
        title: common.title,
        artist: common.artist,
        album: common.album.isEmpty ? null : common.album,
        duration: common.duration,
        coverUri: common.cover?.hasScheme == true ? common.cover : null,
        localUri: Uri.tryParse(href),
      );
    }
    if (!OnlineSource.values.any((candidate) => candidate.id == source)) {
      return null;
    }
    final id = songId.isEmpty ? '${value['id'] ?? ''}' : songId;
    if (id.isEmpty) return null;
    return Track(
      sourceKind: TrackSourceKind.online,
      sourceId: source,
      sourceTrackId: id,
      title: common.title,
      artist: common.artist,
      album: common.album.isEmpty ? null : common.album,
      duration: common.duration,
      coverUri: common.cover?.hasScheme == true ? common.cover : null,
      availableQualities: _qualities(meta),
      extra: {...baseExtra, if (!baseExtra.containsKey('songId')) 'songId': id},
    );
  }

  static List<AudioQuality> _qualities(Map meta) {
    final values = <AudioQuality>{};
    final raw = meta['_qualitys'];
    if (raw is Map) {
      for (final key in raw.keys) {
        final quality = _fromDesktopQuality('$key');
        if (quality != null) values.add(quality);
      }
    }
    final list = meta['qualitys'];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          final quality = _fromDesktopQuality('${item['type'] ?? ''}');
          if (quality != null) values.add(quality);
        }
      }
    }
    return AudioQuality.values.where(values.contains).toList(growable: false);
  }

  static String _desktopQuality(AudioQuality quality) => switch (quality) {
        AudioQuality.master => 'master',
        AudioQuality.atmosPlus => 'atmos_plus',
        AudioQuality.atmos => 'atmos',
        AudioQuality.hires => 'hires',
        AudioQuality.flac24bit => 'flac24bit',
        AudioQuality.flac => 'flac',
        AudioQuality.high320k => '320k',
        AudioQuality.high192k => '192k',
        AudioQuality.standard128k => '128k',
      };

  static AudioQuality? _fromDesktopQuality(String value) => switch (value) {
        'master' => AudioQuality.master,
        'atmos_plus' => AudioQuality.atmosPlus,
        'atmos' => AudioQuality.atmos,
        'hires' => AudioQuality.hires,
        'flac24bit' || 'flac32bit' => AudioQuality.flac24bit,
        'flac' => AudioQuality.flac,
        '320k' => AudioQuality.high320k,
        '192k' => AudioQuality.high192k,
        '128k' => AudioQuality.standard128k,
        _ => null,
      };

  static Duration? _parseDuration(Object? value) {
    final parts = '${value ?? ''}'.split(':').map(int.tryParse).toList();
    if (parts.length < 2 || parts.any((part) => part == null)) return null;
    var seconds = 0;
    for (final part in parts) {
      seconds = seconds * 60 + part!;
    }
    return Duration(seconds: seconds);
  }

  static String? _formatDuration(Duration? duration) {
    if (duration == null) return null;
    final total = duration.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _extension(String value) {
    final name = value.split('/').last;
    final index = name.lastIndexOf('.');
    return index == -1 ? '' : name.substring(index + 1);
  }

  static String _filePath(Uri? uri, String fallback) =>
      uri?.scheme == 'file' ? uri!.toFilePath() : fallback;
}
