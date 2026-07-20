import 'dart:convert';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/library/data/playlist_transfer_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = Track(
    sourceKind: TrackSourceKind.online,
    sourceId: 'tx',
    sourceTrackId: 'song-1',
    title: '测试歌曲',
    artist: '歌手',
    album: '专辑',
    duration: Duration(minutes: 3, seconds: 4),
    availableQualities: [AudioQuality.flac, AudioQuality.high320k],
    extra: {'songId': 7, 'mediaMid': 'media-1'},
  );

  test('exports desktop part v2 and imports it without losing playback ids',
      () {
    final raw = PlaylistTransferCodec.encode(
      UserPlaylist(
        id: 'list-1',
        name: '我的列表',
        position: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [track],
    );
    final exported = jsonDecode(raw) as Map<String, dynamic>;
    final decoded = PlaylistTransferCodec.decode(raw);

    expect(exported['type'], 'playListPart_v2');
    expect(decoded.name, '我的列表');
    expect(decoded.tracks.single.sourceTrackId, '7');
    expect(decoded.tracks.single.extra['mediaMid'], 'media-1');
    expect(decoded.tracks.single.availableQualities, [
      AudioQuality.flac,
      AudioQuality.high320k,
    ]);
  });

  test('drops invalid and duplicate desktop entries', () {
    final decoded = PlaylistTransferCodec.decode(jsonEncode({
      'type': 'playListPart_v2',
      'data': {
        'name': '导入',
        'list': [
          {
            'name': '',
            'source': 'kw',
            'meta': {'songId': '1'}
          },
          {
            'name': '可用',
            'singer': '歌手',
            'source': 'kw',
            'meta': {'songId': '1', 'albumName': ''},
          },
          {
            'name': '重复',
            'singer': '歌手',
            'source': 'kw',
            'meta': {'songId': '1', 'albumName': ''},
          },
        ],
      },
    }));

    expect(decoded.tracks, hasLength(1));
    expect(decoded.tracks.single.title, '可用');
  });
}
