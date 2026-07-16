import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../domain/music.dart';

final libraryStoreProvider = Provider((_) => LibraryStore());

final class LibraryStore {
  static const _databaseName = 'coral_music.db';
  static const _schemaVersion = 3;
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
        },
        onUpgrade: (database, oldVersion, _) async {
          if (oldVersion < 1) await _createV1(database);
          if (oldVersion < 2) await _createV2(database);
          if (oldVersion < 3) await _createV3(database);
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
      );

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
      });

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
    );
  }
}
