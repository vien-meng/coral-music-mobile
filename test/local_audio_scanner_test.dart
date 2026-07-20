import 'dart:convert';
import 'dart:io';

import 'package:coral_music_mobile/features/library/data/local_audio_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scans a local track with its sidecar cover', () async {
    final directory = await Directory.systemTemp.createTemp('coral-audio-');
    try {
      final audio = File('${directory.path}/歌手 - 歌名.mp3');
      await audio.writeAsBytes([0]);
      final cover = File('${directory.path}/cover.jpg');
      await cover.writeAsBytes([0]);

      final result = await LocalAudioScanner().scanDirectory(directory.path);

      expect(result.tracks, hasLength(1));
      expect(result.tracks.single.title, '歌名');
      expect(result.tracks.single.artist, '歌手');
      expect(result.tracks.single.coverUri, cover.absolute.uri);
      expect(result.skipped, isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('uses embedded MP3 labels before the filename fallback', () async {
    final directory = await Directory.systemTemp.createTemp('coral-audio-');
    try {
      final tag = [
        ..._textFrame('TIT2', '嵌入歌名'),
        ..._textFrame('TPE1', '嵌入歌手'),
        ..._textFrame('TALB', '嵌入专辑'),
        ..._textFrame('TYER', '2024'),
        ..._textFrame('TCON', '电子'),
      ];
      final audio = File('${directory.path}/文件名歌手 - 文件名歌名.mp3');
      await audio.writeAsBytes([
        0x49,
        0x44,
        0x33,
        3,
        0,
        0,
        ..._syncSafe(tag.length),
        ...tag,
      ]);

      final result = await LocalAudioScanner().scanFiles([audio.path]);

      expect(result.tracks, hasLength(1));
      expect(result.tracks.single.title, '嵌入歌名');
      expect(result.tracks.single.artist, '嵌入歌手');
      expect(result.tracks.single.album, '嵌入专辑');
      expect(result.tracks.single.extra, {'year': '2024', 'genre': '电子'});
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

List<int> _textFrame(String id, String value) => [
      ...ascii.encode(id),
      0,
      0,
      0,
      utf8.encode(value).length + 1,
      0,
      0,
      3,
      ...utf8.encode(value),
    ];

List<int> _syncSafe(int value) => [
      (value >> 21) & 0x7f,
      (value >> 14) & 0x7f,
      (value >> 7) & 0x7f,
      value & 0x7f,
    ];
