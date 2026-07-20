import 'dart:convert';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/library/data/library_backup_codec.dart';
import 'package:coral_music_mobile/features/library/data/playlist_transfer_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = Track(
    sourceKind: TrackSourceKind.online,
    sourceId: 'kw',
    sourceTrackId: '123',
    title: '歌曲',
    artist: '歌手',
    availableQualities: [AudioQuality.flac],
  );

  test('round trips the local backup preview data', () {
    final raw = LibraryBackupCodec.encode(const LibraryBackup(
      playlists: [
        ImportedPlaylist(name: '列表', tracks: [track])
      ],
      favorites: [track],
      onlineFavorites: [],
      ignoredTracks: [track],
      favoriteAlbums: [
        FavoriteAlbum(key: 'kw:album-1', name: '专辑', tracks: [track])
      ],
    ));
    final decoded = LibraryBackupCodec.decode(raw);

    expect((jsonDecode(raw) as Map)['type'], 'coralMusicMobileBackup_v1');
    expect(decoded.playlists.single.tracks.single.id, track.id);
    expect(decoded.favorites.single.id, track.id);
    expect(decoded.ignoredTracks.single.id, track.id);
    expect(decoded.favoriteAlbums.single.tracks.single.id, track.id);
  });

  test('rejects another JSON document instead of treating it as a backup', () {
    expect(
      () => LibraryBackupCodec.decode('{"type":"playListPart_v2"}'),
      throwsFormatException,
    );
  });
}
