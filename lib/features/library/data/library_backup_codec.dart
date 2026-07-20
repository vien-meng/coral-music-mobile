import 'dart:convert';

import '../../../domain/music.dart';
import 'playlist_transfer_codec.dart';

final class LibraryBackup {
  const LibraryBackup({
    required this.playlists,
    required this.favorites,
    required this.onlineFavorites,
    required this.ignoredTracks,
    this.ignoredKeywords = const [],
  });

  final List<ImportedPlaylist> playlists;
  final List<Track> favorites;
  final List<PlaylistDetail> onlineFavorites;
  final List<Track> ignoredTracks;
  final List<String> ignoredKeywords;

  int get trackCount => playlists.fold(
        favorites.length,
        (count, playlist) => count + playlist.tracks.length,
      );
}

final class LibraryBackupCodec {
  static String encode(LibraryBackup backup) =>
      const JsonEncoder.withIndent('  ').convert({
        'type': 'coralMusicMobileBackup_v1',
        'data': {
          'playlists': backup.playlists
              .map(
                (playlist) => {
                  'name': playlist.name,
                  'tracks': playlist.tracks
                      .map(PlaylistTransferCodec.encodeTrack)
                      .toList(growable: false),
                },
              )
              .toList(growable: false),
          'favorites': backup.favorites
              .map(PlaylistTransferCodec.encodeTrack)
              .toList(growable: false),
          'onlineFavorites':
              backup.onlineFavorites.map(_onlineFavorite).toList(),
          'ignoredTracks': backup.ignoredTracks
              .map(PlaylistTransferCodec.encodeTrack)
              .toList(growable: false),
          'ignoredKeywords': backup.ignoredKeywords,
        },
      });

  static LibraryBackup decode(String raw) {
    final root = jsonDecode(raw);
    if (root is! Map || root['type'] != 'coralMusicMobileBackup_v1') {
      throw const FormatException('不支持的备份文件');
    }
    final data = root['data'];
    if (data is! Map) throw const FormatException('备份文件内容不完整');
    final playlists = _playlists(data['playlists']);
    final favorites = _tracks(data['favorites']);
    final onlineFavorites = _onlineFavorites(data['onlineFavorites']);
    final ignoredTracks = _tracks(data['ignoredTracks']);
    final ignoredKeywords = _keywords(data['ignoredKeywords']);
    return LibraryBackup(
      playlists: playlists,
      favorites: favorites,
      onlineFavorites: onlineFavorites,
      ignoredTracks: ignoredTracks,
      ignoredKeywords: ignoredKeywords,
    );
  }

  static List<ImportedPlaylist> _playlists(Object? raw) {
    if (raw is! List) throw const FormatException('备份列表缺失');
    final values = <ImportedPlaylist>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = '${item['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      values.add(ImportedPlaylist(name: name, tracks: _tracks(item['tracks'])));
    }
    return values;
  }

  static List<Track> _tracks(Object? raw) {
    if (raw is! List) return const [];
    final ids = <String>{};
    final tracks = <Track>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final track = PlaylistTransferCodec.decodeTrack(item);
      if (track != null && ids.add(track.id)) tracks.add(track);
    }
    return tracks;
  }

  static List<String> _keywords(Object? raw) => raw is List
      ? raw
          .whereType<String>()
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty && value.length <= 80)
          .toSet()
          .toList(growable: false)
      : const [];

  static Map<String, Object?> _onlineFavorite(PlaylistDetail detail) => {
        'playlist': {
          'id': detail.playlist.id,
          'source': detail.playlist.source.name,
          'name': detail.playlist.name,
          'author': detail.playlist.author,
          'description': detail.playlist.description,
          'trackCount': detail.playlist.trackCount,
          'playCount': detail.playlist.playCount,
          'coverUri': detail.playlist.coverUri?.toString(),
        },
        'tracks': detail.tracks
            .map(PlaylistTransferCodec.encodeTrack)
            .toList(growable: false),
      };

  static List<PlaylistDetail> _onlineFavorites(Object? raw) {
    if (raw is! List) return const [];
    final result = <PlaylistDetail>[];
    for (final item in raw) {
      if (item is! Map || item['playlist'] is! Map) continue;
      final playlist = item['playlist'] as Map;
      final sourceName = '${playlist['source'] ?? ''}';
      OnlineSource? source;
      for (final candidate in OnlineSource.values) {
        if (candidate.name == sourceName) source = candidate;
      }
      final id = '${playlist['id'] ?? ''}'.trim();
      final name = '${playlist['name'] ?? ''}'.trim();
      if (source == null || id.isEmpty || name.isEmpty) continue;
      result.add(
        PlaylistDetail(
          playlist: OnlinePlaylist(
            id: id,
            source: source,
            name: name,
            author: '${playlist['author'] ?? ''}',
            description: '${playlist['description'] ?? ''}',
            trackCount: (playlist['trackCount'] as num?)?.toInt() ?? 0,
            playCount: '${playlist['playCount'] ?? ''}',
            coverUri: Uri.tryParse('${playlist['coverUri'] ?? ''}'),
          ),
          tracks: _tracks(item['tracks']),
        ),
      );
    }
    return result;
  }
}
