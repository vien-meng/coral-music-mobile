enum OnlineSource {
  kuwo('kw', '酷我音乐'),
  kugou('kg', '酷狗音乐'),
  qq('tx', 'QQ音乐'),
  netease('wy', '网易云音乐'),
  migu('mg', '咪咕音乐');

  const OnlineSource(this.id, this.label);

  final String id;
  final String label;
}

enum TrackSourceKind { online, local, download, webdav }

enum AudioQuality {
  master,
  atmosPlus,
  atmos,
  hires,
  flac24bit,
  flac,
  high320k,
  high192k,
  standard128k,
}

/// SQ is lossless FLAC. When unavailable, use the best quality the source
/// declares instead of advertising a quality it cannot serve.
AudioQuality defaultPlaybackQuality(Iterable<AudioQuality> qualities) {
  final values = qualities.toSet();
  if (values.contains(AudioQuality.flac)) return AudioQuality.flac;
  if (values.isEmpty) return AudioQuality.flac;
  return values.reduce(
      (best, candidate) => candidate.index < best.index ? candidate : best);
}

enum PlaybackMode { listLoop, singleLoop, shuffle }

final class LyricPayload {
  const LyricPayload({
    this.lyric = '',
    this.lxlyric = '',
    this.tlyric = '',
    this.rlyric = '',
  });

  final String lyric;
  final String lxlyric;
  final String tlyric;
  final String rlyric;
}

final class Track {
  const Track({
    required this.sourceKind,
    required this.sourceId,
    required this.sourceTrackId,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.coverUri,
    this.localUri,
    this.availableQualities = const [],
    this.extra = const {},
  });

  final TrackSourceKind sourceKind;
  final String sourceId;
  final String sourceTrackId;
  final String title;
  final String artist;
  final String? album;
  final Duration? duration;
  final Uri? coverUri;
  final Uri? localUri;
  final List<AudioQuality> availableQualities;
  final Map<String, Object?> extra;

  String get id => '${sourceKind.name}:$sourceId:$sourceTrackId';
}

final class LeaderboardBoard {
  const LeaderboardBoard({
    required this.id,
    required this.source,
    required this.name,
    required this.remoteId,
  });

  final String id;
  final OnlineSource source;
  final String name;
  final String remoteId;
}

final class OnlinePlaylist {
  const OnlinePlaylist({
    required this.id,
    required this.source,
    required this.name,
    this.author = '',
    this.description = '',
    this.trackCount = 0,
    this.playCount = '',
    this.coverUri,
  });

  final String id;
  final OnlineSource source;
  final String name;
  final String author;
  final String description;
  final int trackCount;
  final String playCount;
  final Uri? coverUri;
}

final class PlaylistDetail {
  const PlaylistDetail({required this.playlist, required this.tracks});

  final OnlinePlaylist playlist;
  final List<Track> tracks;
}

final class UserPlaylist {
  const UserPlaylist({
    required this.id,
    required this.name,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class PlayHistoryEntry {
  const PlayHistoryEntry({
    required this.track,
    required this.playedAt,
    required this.playCount,
    required this.lastPosition,
  });

  final Track track;
  final DateTime playedAt;
  final int playCount;
  final Duration lastPosition;
}

final class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < total;
}
