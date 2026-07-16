import 'dart:io';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/data/local_lyric_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers an LRC beside a local track', () async {
    final directory = await Directory.systemTemp.createTemp('coral-lrc-');
    addTearDown(() => directory.delete(recursive: true));
    final song = File('${directory.path}/song.mp3');
    final lyric = File('${directory.path}/song.lrc');
    await song.writeAsBytes(const []);
    await lyric.writeAsString('[00:01.00]本地歌词');

    final result = await LocalLyricLoader().load(Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'local',
      sourceTrackId: 'song',
      title: '歌曲',
      artist: '歌手',
      localUri: song.uri,
    ));

    expect(result?.lyric, '[00:01.00]本地歌词');
  });
}
