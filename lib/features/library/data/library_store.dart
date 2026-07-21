import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../domain/music.dart';
import 'library_backup_codec.dart';
import 'playlist_transfer_codec.dart';

final libraryStoreProvider = Provider((_) => LibraryStore());

final class SavedPlaybackQueue {
  const SavedPlaybackQueue({
    required this.tracks,
    required this.currentIndex,
    required this.mode,
    this.contextId,
  });

  final List<Track> tracks;
  final int currentIndex;
  final PlaybackMode mode;
  final String? contextId;
}

bool matchesIgnoredKeyword(Track track, String keyword) => [
      track.title,
      track.artist,
      track.album ?? ''
    ].join('\n').toLowerCase().contains(keyword.trim().toLowerCase());

final class LibraryStore {
  static const _databaseName = 'coral_music.db';
  static const _schemaVersion = 11;
  static const favoritesId = 'favorites';

  late final Future<Database> _database = _open();

  Future<List<UserPlaylist>> listPlaylists() async {
    final database = await _database;
    final rows = await database.query(
      'user_playlist',
      where: 'id != ?',
      whereArgs: const [favoritesId],
      orderBy: 'position ASC, created_at ASC',
    );
    return rows.map(_playlistFromRow).toList(growable: false);
  }

  Future<UserPlaylist> createPlaylist(String name) async {
    final database = await _database;
    final now = DateTime.now();
    final id = 'playlist-${now.microsecondsSinceEpoch}';
    final lastPosition = Sqflite.firstIntValue(
          await database.rawQuery(
            'SELECT MAX(position) FROM user_playlist',
          ),
        ) ??
        -1;
    final playlist = UserPlaylist(
      id: id,
      name: name,
      position: lastPosition + 1,
      createdAt: now,
      updatedAt: now,
    );
    await database.insert('user_playlist', _playlistToRow(playlist));
    return playlist;
  }

  Future<({UserPlaylist playlist, int added, int skipped})> importPlaylist(
    ImportedPlaylist imported,
  ) async {
    final database = await _database;
    return database.transaction((transaction) async {
      final now = DateTime.now();
      final lastPosition = Sqflite.firstIntValue(
            await transaction
                .rawQuery('SELECT MAX(position) FROM user_playlist'),
          ) ??
          -1;
      final playlist = UserPlaylist(
        id: 'playlist-${now.microsecondsSinceEpoch}',
        name: imported.name,
        position: lastPosition + 1,
        createdAt: now,
        updatedAt: now,
      );
      await transaction.insert('user_playlist', _playlistToRow(playlist));
      final added =
          await _appendTracks(transaction, playlist.id, imported.tracks);
      return (
        playlist: playlist,
        added: added,
        skipped: imported.tracks.length - added,
      );
    });
  }

  Future<String> exportPlaylist(UserPlaylist playlist) async =>
      PlaylistTransferCodec.encode(playlist, await listTracks(playlist.id));

  Future<String> exportLibraryBackup() async {
    final playlists = await listPlaylists();
    final tracks = await Future.wait(
      playlists.map((playlist) async => ImportedPlaylist(
            name: playlist.name,
            tracks: await listTracks(playlist.id),
          )),
    );
    return LibraryBackupCodec.encode(LibraryBackup(
      playlists: tracks,
      favorites: await listFavorites(),
      onlineFavorites: await listFavoriteOnlinePlaylists(),
      favoriteAlbums: await listFavoriteAlbums(),
      ignoredTracks: await listIgnoredTracks(),
      ignoredKeywords: await listIgnoredKeywords(),
    ));
  }

  Future<void> savePlaybackQueue({
    required List<Track> tracks,
    required int currentIndex,
    required PlaybackMode mode,
    String? contextId,
  }) async {
    final database = await _database;
    if (tracks.isEmpty) {
      await database.delete('playback_queue', where: 'id = 1');
      return;
    }
    await database.insert(
      'playback_queue',
      {
        'id': 1,
        'tracks_json': jsonEncode(
          tracks.map(_trackSnapshot).toList(growable: false),
        ),
        'current_index': currentIndex,
        'context_id': contextId,
        'mode': mode.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SavedPlaybackQueue?> loadPlaybackQueue() async {
    final database = await _database;
    final rows = await database.query(
      'playback_queue',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    try {
      final encodedTracks = jsonDecode(row['tracks_json']! as String) as List;
      final tracks = encodedTracks
          .whereType<String>()
          .map(_trackFromSnapshot)
          .toList(growable: false);
      final mode = PlaybackMode.values.byName(row['mode']! as String);
      if (tracks.isEmpty) throw const FormatException('empty playback queue');
      return SavedPlaybackQueue(
        tracks: tracks,
        currentIndex: row['current_index']! as int,
        contextId: row['context_id'] as String?,
        mode: mode,
      );
    } on Object {
      await database.delete('playback_queue', where: 'id = 1');
      return null;
    }
  }

  Future<List<String>> listSearchHistory() async {
    final database = await _database;
    final rows = await database.query(
      'search_history',
      columns: const ['keyword'],
      orderBy: 'searched_at DESC',
      limit: 20,
    );
    return rows.map((row) => row['keyword']! as String).toList(growable: false);
  }

  Future<void> recordSearchHistory(String value) async {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    final database = await _database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'search_history',
        where: 'keyword = ?',
        whereArgs: [keyword],
      );
      await transaction.insert('search_history', {
        'keyword': keyword,
        'searched_at': DateTime.now().millisecondsSinceEpoch,
      });
      await transaction.rawDelete('''
        DELETE FROM search_history WHERE keyword IN (
          SELECT keyword FROM search_history
          ORDER BY searched_at DESC
          LIMIT -1 OFFSET 20
        )
      ''');
    });
  }

  Future<void> clearSearchHistory() async {
    final database = await _database;
    await database.delete('search_history');
  }

  Future<({int playlists, int tracks, int favorites, int ignored})>
      restoreLibraryBackup(LibraryBackup backup) async {
    final database = await _database;
    return database.transaction((transaction) async {
      var playlistCount = 0;
      var trackCount = 0;
      final now = DateTime.now();
      for (var index = 0; index < backup.playlists.length; index++) {
        final imported = backup.playlists[index];
        final position = Sqflite.firstIntValue(
              await transaction
                  .rawQuery('SELECT MAX(position) FROM user_playlist'),
            ) ??
            -1;
        final playlist = UserPlaylist(
          id: 'playlist-${now.microsecondsSinceEpoch}-$index',
          name: imported.name,
          position: position + 1,
          createdAt: now,
          updatedAt: now,
        );
        await transaction.insert('user_playlist', _playlistToRow(playlist));
        playlistCount++;
        trackCount +=
            await _appendTracks(transaction, playlist.id, imported.tracks);
      }
      final favoriteCount =
          await _restoreFavoriteTracks(transaction, backup.favorites);
      for (final detail in backup.onlineFavorites) {
        await transaction.insert(
            'online_playlist_favorite',
            {
              'playlist_key': _onlinePlaylistKey(detail.playlist),
              'playlist_json': _onlinePlaylistSnapshot(detail.playlist),
              'tracks_json': jsonEncode(
                detail.tracks.map(_trackSnapshot).toList(growable: false),
              ),
              'saved_at': now.millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final album in backup.favoriteAlbums) {
        await transaction.insert(
          'album_favorite',
          _favoriteAlbumToRow(album, savedAt: now.millisecondsSinceEpoch),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      var ignoredCount = 0;
      for (final track in backup.ignoredTracks) {
        ignoredCount += await transaction.insert(
            'ignored_track',
            {
              'track_id': track.id,
              'track_json': _trackSnapshot(track),
              'created_at': now.millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final keyword in backup.ignoredKeywords) {
        ignoredCount += await transaction.insert(
            'ignored_keyword',
            {
              'keyword': keyword,
              'created_at': now.millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return (
        playlists: playlistCount,
        tracks: trackCount,
        favorites: favoriteCount,
        ignored: ignoredCount,
      );
    });
  }

  Future<void> renamePlaylist(UserPlaylist playlist, String name) async {
    final database = await _database;
    await database.update(
      'user_playlist',
      {'name': name, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [playlist.id],
    );
  }

  Future<void> deletePlaylist(String id) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'user_playlist_track',
        where: 'playlist_id = ?',
        whereArgs: [id],
      );
      await transaction.delete(
        'user_playlist',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<bool> addTrack(String playlistId, Track track) async {
    final database = await _database;
    final lastPosition = Sqflite.firstIntValue(
          await database.rawQuery(
            'SELECT MAX(position) FROM user_playlist_track WHERE playlist_id = ?',
            [playlistId],
          ),
        ) ??
        -1;
    final inserted = await database.insert(
      'user_playlist_track',
      _trackToRow(playlistId, track, lastPosition + 1),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return inserted != 0;
  }

  Future<List<Track>> listTracks(String playlistId) async {
    final database = await _database;
    final rows = await database.query(
      'user_playlist_track',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );
    return rows.map(_trackFromRow).toList(growable: false);
  }

  Future<List<Track>> listLibraryTracks() async {
    final playlists = await listPlaylists();
    final albums = await listFavoriteAlbums();
    final lists = await Future.wait([
      ...playlists.map((playlist) => listTracks(playlist.id)),
      listFavorites(),
      ...albums.map((album) async => album.tracks),
    ]);
    final downloaded = (await Future.wait(
      (await listDownloadTasks())
          .where((task) => task.status == DownloadStatus.completed)
          .map(_downloadedTrack),
    ))
        .whereType<Track>()
        .toList(growable: false);
    final byId = <String, Track>{};
    for (final tracks in [...lists, downloaded]) {
      for (final track in tracks) {
        byId.putIfAbsent(track.id, () => track);
      }
    }
    return byId.values.toList(growable: false);
  }

  Future<List<Track>> filterIgnored(Iterable<Track> tracks) async {
    final database = await _database;
    final results = await Future.wait([
      database.query('ignored_track', columns: ['track_id']),
      database.query('ignored_keyword', columns: ['keyword']),
    ]);
    final ignored = results[0].map((row) => row['track_id']! as String).toSet();
    final keywords = results[1]
        .map((row) => row['keyword']! as String)
        .toList(growable: false);
    return tracks.where((track) {
      if (ignored.contains(track.id)) return false;
      return !keywords.any((keyword) => matchesIgnoredKeyword(track, keyword));
    }).toList();
  }

  Future<bool> isIgnored(Track track) async {
    final database = await _database;
    final rows = await database.query(
      'ignored_track',
      columns: const ['track_id'],
      where: 'track_id = ?',
      whereArgs: [track.id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Track>> listIgnoredTracks() async {
    final database = await _database;
    final rows =
        await database.query('ignored_track', orderBy: 'created_at DESC');
    return rows
        .map((row) => _trackFromSnapshot(row['track_json']! as String))
        .toList(growable: false);
  }

  Future<void> clearIgnored() async {
    final database = await _database;
    await database.delete('ignored_track');
  }

  Future<List<String>> listIgnoredKeywords() async {
    final database = await _database;
    final rows = await database.query(
      'ignored_keyword',
      orderBy: 'created_at DESC',
    );
    return rows.map((row) => row['keyword']! as String).toList(growable: false);
  }

  Future<void> addIgnoredKeyword(String value) async {
    final keyword = value.trim().toLowerCase();
    if (keyword.isEmpty || keyword.length > 80) {
      throw const FormatException('关键词长度应为 1 到 80 个字符');
    }
    final database = await _database;
    await database.insert(
      'ignored_keyword',
      {'keyword': keyword, 'created_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeIgnoredKeyword(String keyword) async {
    final database = await _database;
    await database.delete(
      'ignored_keyword',
      where: 'keyword = ?',
      whereArgs: [keyword],
    );
  }

  Future<void> clearIgnoredKeywords() async {
    final database = await _database;
    await database.delete('ignored_keyword');
  }

  Future<bool> toggleIgnored(Track track) async {
    final database = await _database;
    if (await isIgnored(track)) {
      await database.delete('ignored_track',
          where: 'track_id = ?', whereArgs: [track.id]);
      return false;
    }
    await database.insert('ignored_track', {
      'track_id': track.id,
      'track_json': _trackSnapshot(track),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return true;
  }

  Future<Track?> _downloadedTrack(DownloadTask task) async {
    if (task.targetPath.isEmpty || !await File(task.targetPath).exists()) {
      return null;
    }
    final track = task.track;
    return Track(
      sourceKind: TrackSourceKind.download,
      sourceId: 'downloads',
      sourceTrackId: task.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      coverUri: track.coverUri,
      localUri: File(task.targetPath).absolute.uri,
      availableQualities: [task.quality],
      extra: track.extra,
    );
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    final database = await _database;
    await database.delete(
      'user_playlist_track',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
  }

  Future<void> removeTracks(
      String playlistId, Iterable<String> trackIds) async {
    final ids = trackIds.toList(growable: false);
    if (ids.isEmpty) return;
    final database = await _database;
    await database.transaction((transaction) async {
      final batch = transaction.batch();
      for (final id in ids) {
        batch.delete(
          'user_playlist_track',
          where: 'playlist_id = ? AND track_id = ?',
          whereArgs: [playlistId, id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> saveTrackOrder(String playlistId, List<String> trackIds) async {
    final database = await _database;
    await database.transaction((transaction) async {
      final batch = transaction.batch();
      for (var index = 0; index < trackIds.length; index++) {
        batch.update(
          'user_playlist_track',
          {'position': index},
          where: 'playlist_id = ? AND track_id = ?',
          whereArgs: [playlistId, trackIds[index]],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> transferTracks({
    required String fromPlaylistId,
    required String toPlaylistId,
    required Iterable<Track> tracks,
    required bool move,
  }) async {
    if (fromPlaylistId == toPlaylistId) return 0;
    final sourceTracks = tracks.toList(growable: false);
    if (sourceTracks.isEmpty) return 0;
    final database = await _database;
    return database.transaction((transaction) async {
      final added =
          await _appendTracks(transaction, toPlaylistId, sourceTracks);
      if (move) {
        for (final track in sourceTracks) {
          await transaction.delete(
            'user_playlist_track',
            where: 'playlist_id = ? AND track_id = ?',
            whereArgs: [fromPlaylistId, track.id],
          );
        }
      }
      return added;
    });
  }

  Future<List<Track>> listFavorites() => listTracks(favoritesId);

  Future<bool> isFavorite(String trackId) async {
    final database = await _database;
    final result = await database.query(
      'user_playlist_track',
      columns: const ['track_id'],
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [favoritesId, trackId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<bool> toggleFavorite(Track track) async {
    final database = await _database;
    return database.transaction((transaction) async {
      final exists = await transaction.query(
        'user_playlist_track',
        columns: const ['track_id'],
        where: 'playlist_id = ? AND track_id = ?',
        whereArgs: [favoritesId, track.id],
        limit: 1,
      );
      if (exists.isNotEmpty) {
        await transaction.delete(
          'user_playlist_track',
          where: 'playlist_id = ? AND track_id = ?',
          whereArgs: [favoritesId, track.id],
        );
        return false;
      }
      final now = DateTime.now();
      await transaction.insert(
        'user_playlist',
        _playlistToRow(
          UserPlaylist(
            id: favoritesId,
            name: '我的收藏',
            position: -1,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final lastPosition = Sqflite.firstIntValue(
            await transaction.rawQuery(
              'SELECT MAX(position) FROM user_playlist_track WHERE playlist_id = ?',
              [favoritesId],
            ),
          ) ??
          -1;
      await transaction.insert(
        'user_playlist_track',
        _trackToRow(favoritesId, track, lastPosition + 1),
      );
      return true;
    });
  }

  Future<List<PlaylistDetail>> listFavoriteOnlinePlaylists() async {
    final database = await _database;
    final rows = await database.query(
      'online_playlist_favorite',
      orderBy: 'saved_at DESC',
    );
    return rows
        .map(
          (row) => PlaylistDetail(
            playlist: _onlinePlaylistFromSnapshot(
              row['playlist_json']! as String,
            ),
            tracks: (jsonDecode(row['tracks_json']! as String) as List)
                .whereType<String>()
                .map(_trackFromSnapshot)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> isFavoriteOnlinePlaylist(OnlinePlaylist playlist) async {
    final database = await _database;
    final rows = await database.query(
      'online_playlist_favorite',
      columns: const ['playlist_key'],
      where: 'playlist_key = ?',
      whereArgs: [_onlinePlaylistKey(playlist)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> toggleFavoriteOnlinePlaylist(PlaylistDetail detail) async {
    final database = await _database;
    final key = _onlinePlaylistKey(detail.playlist);
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'online_playlist_favorite',
        columns: const ['playlist_key'],
        where: 'playlist_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        await transaction.delete(
          'online_playlist_favorite',
          where: 'playlist_key = ?',
          whereArgs: [key],
        );
        return false;
      }
      await transaction.insert('online_playlist_favorite', {
        'playlist_key': key,
        'playlist_json': _onlinePlaylistSnapshot(detail.playlist),
        'tracks_json': jsonEncode(
          detail.tracks.map(_trackSnapshot).toList(growable: false),
        ),
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
  }

  Future<List<FavoriteAlbum>> listFavoriteAlbums() async {
    final database = await _database;
    final rows =
        await database.query('album_favorite', orderBy: 'saved_at DESC');
    return rows
        .map(
          (row) => FavoriteAlbum(
            key: row['album_key']! as String,
            name: row['name']! as String,
            artist: row['artist']! as String,
            coverUri: Uri.tryParse('${row['cover_uri'] ?? ''}'),
            tracks: (jsonDecode(row['tracks_json']! as String) as List)
                .whereType<String>()
                .map(_trackFromSnapshot)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> toggleFavoriteAlbum(String name, List<Track> tracks) async {
    if (name.trim().isEmpty || tracks.isEmpty) return false;
    final database = await _database;
    final album = _favoriteAlbum(name, tracks);
    return database.transaction((transaction) async {
      final exists = await transaction.query(
        'album_favorite',
        columns: const ['album_key'],
        where: 'album_key = ?',
        whereArgs: [album.key],
        limit: 1,
      );
      if (exists.isNotEmpty) {
        await transaction.delete(
          'album_favorite',
          where: 'album_key = ?',
          whereArgs: [album.key],
        );
        return false;
      }
      await transaction.insert(
        'album_favorite',
        _favoriteAlbumToRow(
          album,
          savedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return true;
    });
  }

  Future<bool> isFavoriteAlbum(String name, List<Track> tracks) async {
    if (name.trim().isEmpty || tracks.isEmpty) return false;
    final database = await _database;
    final rows = await database.query(
      'album_favorite',
      columns: const ['album_key'],
      where: 'album_key = ?',
      whereArgs: [_favoriteAlbum(name, tracks).key],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<DownloadTask>> listDownloadTasks() async {
    final database = await _database;
    final rows =
        await database.query('download_task', orderBy: 'created_at DESC');
    return rows
        .map(
          (row) => DownloadTask(
            id: row['id']! as String,
            track: _trackFromSnapshot(row['track_json']! as String),
            quality: AudioQuality.values.byName(row['quality']! as String),
            status: DownloadStatus.values.byName(row['status']! as String),
            targetPath: row['target_path']! as String,
            createdAt:
                DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
            progress: (row['progress']! as num).toDouble(),
            error: row['error'] as String?,
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveDownloadTask(DownloadTask task) async {
    final database = await _database;
    await database.insert(
        'download_task',
        {
          'id': task.id,
          'track_json': _trackSnapshot(task.track),
          'quality': task.quality.name,
          'status': task.status.name,
          'target_path': task.targetPath,
          'created_at': task.createdAt.millisecondsSinceEpoch,
          'progress': task.progress,
          'error': task.error,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteDownloadTask(String id) async {
    final database = await _database;
    await database.delete('download_task', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PlayHistoryEntry>> listHistory() async {
    final database = await _database;
    final rows = await database.query(
      'play_history',
      orderBy: 'played_at DESC',
    );
    return rows
        .map(
          (row) => PlayHistoryEntry(
            track: _trackFromSnapshot(row['track_json']! as String),
            playedAt: DateTime.fromMillisecondsSinceEpoch(
              row['played_at']! as int,
            ),
            playCount: row['play_count']! as int,
            lastPosition: Duration(
              milliseconds: row['last_position_ms']! as int,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> recordHistory(Track track, Duration position) async {
    final database = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction((transaction) async {
      await transaction.rawInsert('''
        INSERT INTO play_history (
          track_id, track_json, played_at, play_count, last_position_ms
        ) VALUES (?, ?, ?, 1, ?)
        ON CONFLICT(track_id) DO UPDATE SET
          track_json = excluded.track_json,
          played_at = excluded.played_at,
          play_count = play_history.play_count + 1,
          last_position_ms = excluded.last_position_ms
      ''', [track.id, _trackSnapshot(track), now, position.inMilliseconds]);
      await transaction.rawDelete('''
        DELETE FROM play_history WHERE track_id IN (
          SELECT track_id FROM play_history
          ORDER BY played_at DESC
          LIMIT -1 OFFSET 1000
        )
      ''');
    });
  }

  Future<void> updateHistoryPosition(String trackId, Duration position) async {
    final database = await _database;
    await database.update(
      'play_history',
      {
        'last_position_ms': position.inMilliseconds,
        'played_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
  }

  Future<void> clearHistory() async {
    final database = await _database;
    await database.delete('play_history');
  }

  Future<void> saveOrder(List<String> ids) async {
    final database = await _database;
    await database.transaction((transaction) async {
      final batch = transaction.batch();
      for (var index = 0; index < ids.length; index++) {
        batch.update(
          'user_playlist',
          {
            'position': index,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [ids[index]],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Database> _open() async => openDatabase(
        '${await getDatabasesPath()}/$_databaseName',
        version: _schemaVersion,
        onCreate: (database, _) async {
          await _createV1(database);
          await _createV2(database);
          await _createV3(database);
          await _createV4(database);
          await _createV5(database);
          await _createV6(database);
          await _createV7(database);
          await _createV8(database);
          await _createV9(database);
          await _createV10(database);
          await _createV11(database);
        },
        onUpgrade: (database, oldVersion, _) async {
          if (oldVersion < 1) await _createV1(database);
          if (oldVersion < 2) await _createV2(database);
          if (oldVersion < 3) await _createV3(database);
          if (oldVersion < 4) await _createV4(database);
          if (oldVersion < 5) await _createV5(database);
          if (oldVersion < 6) await _createV6(database);
          if (oldVersion < 7) await _createV7(database);
          if (oldVersion < 8) await _createV8(database);
          if (oldVersion < 9) await _createV9(database);
          if (oldVersion < 10) await _createV10(database);
          if (oldVersion < 11) await _createV11(database);
        },
      );

  Future<void> _createV1(DatabaseExecutor database) => database.execute('''
    CREATE TABLE user_playlist (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      position INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  Future<void> _createV2(DatabaseExecutor database) => database.execute('''
    CREATE TABLE user_playlist_track (
      playlist_id TEXT NOT NULL,
      track_id TEXT NOT NULL,
      source_kind TEXT NOT NULL,
      source_id TEXT NOT NULL,
      source_track_id TEXT NOT NULL,
      title TEXT NOT NULL,
      artist TEXT NOT NULL,
      album TEXT,
      duration_ms INTEGER,
      cover_uri TEXT,
      local_uri TEXT,
      qualities_json TEXT NOT NULL,
      position INTEGER NOT NULL,
      PRIMARY KEY (playlist_id, track_id)
    )
  ''');

  Future<void> _createV3(DatabaseExecutor database) => database.execute('''
    CREATE TABLE play_history (
      track_id TEXT PRIMARY KEY NOT NULL,
      track_json TEXT NOT NULL,
      played_at INTEGER NOT NULL,
      play_count INTEGER NOT NULL,
      last_position_ms INTEGER NOT NULL
    )
  ''');

  Future<void> _createV4(DatabaseExecutor database) => database.execute('''
    CREATE TABLE online_playlist_favorite (
      playlist_key TEXT PRIMARY KEY NOT NULL,
      playlist_json TEXT NOT NULL,
      tracks_json TEXT NOT NULL,
      saved_at INTEGER NOT NULL
    )
  ''');

  Future<void> _createV5(DatabaseExecutor database) => database.execute('''
    CREATE TABLE download_task (
      id TEXT PRIMARY KEY NOT NULL,
      track_json TEXT NOT NULL,
      quality TEXT NOT NULL,
      status TEXT NOT NULL,
      target_path TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      progress REAL NOT NULL,
      error TEXT
    )
  ''');

  Future<void> _createV6(DatabaseExecutor database) => database.execute('''
    ALTER TABLE user_playlist_track
    ADD COLUMN extra_json TEXT NOT NULL DEFAULT '{}'
  ''');

  Future<void> _createV7(DatabaseExecutor database) => database.execute('''
    CREATE TABLE ignored_track (
      track_id TEXT PRIMARY KEY NOT NULL,
      track_json TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');

  Future<void> _createV8(DatabaseExecutor database) => database.execute('''
    CREATE TABLE ignored_keyword (
      keyword TEXT PRIMARY KEY NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');

  Future<void> _createV9(DatabaseExecutor database) => database.execute('''
    CREATE TABLE playback_queue (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      tracks_json TEXT NOT NULL,
      current_index INTEGER NOT NULL,
      context_id TEXT,
      mode TEXT NOT NULL
    )
  ''');

  Future<void> _createV10(DatabaseExecutor database) => database.execute('''
    CREATE TABLE search_history (
      keyword TEXT PRIMARY KEY NOT NULL,
      searched_at INTEGER NOT NULL
    )
  ''');

  Future<void> _createV11(DatabaseExecutor database) => database.execute('''
    CREATE TABLE album_favorite (
      album_key TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      artist TEXT NOT NULL,
      cover_uri TEXT,
      tracks_json TEXT NOT NULL,
      saved_at INTEGER NOT NULL
    )
  ''');

  UserPlaylist _playlistFromRow(Map<String, Object?> row) => UserPlaylist(
        id: row['id']! as String,
        name: row['name']! as String,
        position: row['position']! as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at']! as int,
        ),
      );

  Map<String, Object> _playlistToRow(UserPlaylist playlist) => {
        'id': playlist.id,
        'name': playlist.name,
        'position': playlist.position,
        'created_at': playlist.createdAt.millisecondsSinceEpoch,
        'updated_at': playlist.updatedAt.millisecondsSinceEpoch,
      };

  Map<String, Object?> _trackToRow(
    String playlistId,
    Track track,
    int position,
  ) =>
      {
        'playlist_id': playlistId,
        'track_id': track.id,
        'source_kind': track.sourceKind.name,
        'source_id': track.sourceId,
        'source_track_id': track.sourceTrackId,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'duration_ms': track.duration?.inMilliseconds,
        'cover_uri': track.coverUri?.toString(),
        'local_uri': track.localUri?.toString(),
        'qualities_json': jsonEncode(
          track.availableQualities.map((quality) => quality.name).toList(),
        ),
        'extra_json': jsonEncode(track.extra),
        'position': position,
      };

  Track _trackFromRow(Map<String, Object?> row) => Track(
        sourceKind:
            TrackSourceKind.values.byName(row['source_kind']! as String),
        sourceId: row['source_id']! as String,
        sourceTrackId: row['source_track_id']! as String,
        title: row['title']! as String,
        artist: row['artist']! as String,
        album: row['album'] as String?,
        duration: switch (row['duration_ms']) {
          final int milliseconds => Duration(milliseconds: milliseconds),
          _ => null,
        },
        coverUri: switch (row['cover_uri']) {
          final String uri => Uri.tryParse(uri),
          _ => null,
        },
        localUri: switch (row['local_uri']) {
          final String uri => Uri.tryParse(uri),
          _ => null,
        },
        availableQualities:
            (jsonDecode(row['qualities_json']! as String) as List<dynamic>)
                .whereType<String>()
                .map(AudioQuality.values.byName)
                .toList(growable: false),
        extra: _extraFromJson(row['extra_json'] as String?),
      );

  Future<int> _appendTracks(
    DatabaseExecutor database,
    String playlistId,
    List<Track> tracks,
  ) async {
    var position = Sqflite.firstIntValue(
          await database.rawQuery(
            'SELECT MAX(position) FROM user_playlist_track WHERE playlist_id = ?',
            [playlistId],
          ),
        ) ??
        -1;
    var added = 0;
    for (final track in tracks) {
      final inserted = await database.insert(
        'user_playlist_track',
        _trackToRow(playlistId, track, position + 1),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (inserted != 0) {
        position++;
        added++;
      }
    }
    return added;
  }

  Future<int> _restoreFavoriteTracks(
    DatabaseExecutor database,
    List<Track> tracks,
  ) async {
    if (tracks.isEmpty) return 0;
    final now = DateTime.now();
    await database.insert(
      'user_playlist',
      _playlistToRow(UserPlaylist(
        id: favoritesId,
        name: '我的收藏',
        position: -1,
        createdAt: now,
        updatedAt: now,
      )),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return _appendTracks(database, favoritesId, tracks);
  }

  String _trackSnapshot(Track track) => jsonEncode({
        'source_kind': track.sourceKind.name,
        'source_id': track.sourceId,
        'source_track_id': track.sourceTrackId,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'duration_ms': track.duration?.inMilliseconds,
        'cover_uri': track.coverUri?.toString(),
        'local_uri': track.localUri?.toString(),
        'qualities': track.availableQualities
            .map((quality) => quality.name)
            .toList(growable: false),
        'extra': track.extra,
      });

  String _onlinePlaylistKey(OnlinePlaylist playlist) =>
      '${playlist.source.id}:${playlist.id}';

  FavoriteAlbum _favoriteAlbum(String name, List<Track> tracks) {
    final first = tracks.first;
    final albumId =
        '${first.extra['albumId'] ?? first.extra['albumMid'] ?? ''}'.trim();
    final artist = first.artist.trim();
    final key = albumId.isNotEmpty
        ? '${first.sourceId}:$albumId'
        : '${first.sourceId}:${name.trim().toLowerCase()}:${artist.toLowerCase()}';
    return FavoriteAlbum(
      key: key,
      name: name.trim(),
      artist: artist,
      coverUri: first.coverUri,
      tracks: tracks,
    );
  }

  Map<String, Object?> _favoriteAlbumToRow(
    FavoriteAlbum album, {
    required int savedAt,
  }) =>
      {
        'album_key': album.key,
        'name': album.name,
        'artist': album.artist,
        'cover_uri': album.coverUri?.toString(),
        'tracks_json': jsonEncode(
          album.tracks.map(_trackSnapshot).toList(growable: false),
        ),
        'saved_at': savedAt,
      };

  String _onlinePlaylistSnapshot(OnlinePlaylist playlist) => jsonEncode({
        'id': playlist.id,
        'source': playlist.source.name,
        'name': playlist.name,
        'author': playlist.author,
        'description': playlist.description,
        'track_count': playlist.trackCount,
        'play_count': playlist.playCount,
        'cover_uri': playlist.coverUri?.toString(),
      });

  OnlinePlaylist _onlinePlaylistFromSnapshot(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return OnlinePlaylist(
      id: data['id'] as String,
      source: OnlineSource.values.byName(data['source'] as String),
      name: data['name'] as String,
      author: data['author'] as String? ?? '',
      description: data['description'] as String? ?? '',
      trackCount: data['track_count'] as int? ?? 0,
      playCount: data['play_count'] as String? ?? '',
      coverUri: switch (data['cover_uri']) {
        final String uri => Uri.tryParse(uri),
        _ => null,
      },
    );
  }

  Track _trackFromSnapshot(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return Track(
      sourceKind: TrackSourceKind.values.byName(data['source_kind'] as String),
      sourceId: data['source_id'] as String,
      sourceTrackId: data['source_track_id'] as String,
      title: data['title'] as String,
      artist: data['artist'] as String,
      album: data['album'] as String?,
      duration: switch (data['duration_ms']) {
        final int milliseconds => Duration(milliseconds: milliseconds),
        _ => null,
      },
      coverUri: switch (data['cover_uri']) {
        final String uri => Uri.tryParse(uri),
        _ => null,
      },
      localUri: switch (data['local_uri']) {
        final String uri => Uri.tryParse(uri),
        _ => null,
      },
      availableQualities: (data['qualities'] as List<dynamic>)
          .whereType<String>()
          .map(AudioQuality.values.byName)
          .toList(growable: false),
      extra: (data['extra'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          const {},
    );
  }

  Map<String, Object?> _extraFromJson(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final value = jsonDecode(raw);
      return (value as Map?)?.map(
            (key, item) => MapEntry(key.toString(), item),
          ) ??
          const {};
    } on FormatException {
      return const {};
    }
  }
}
