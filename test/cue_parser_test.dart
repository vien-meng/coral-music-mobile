import 'dart:io';

import 'package:coral_music_mobile/features/library/data/cue_parser.dart';
import 'package:coral_music_mobile/features/library/data/local_audio_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports a CUE as timed tracks without the raw duplicate', () async {
    final directory = await Directory.systemTemp.createTemp('coral-cue-');
    addTearDown(() => directory.delete(recursive: true));
    const totalSamples = 44100 * 300;
    final flac = List<int>.filled(38, 0)
      ..setRange(0, 4, 'fLaC'.codeUnits)
      ..[4] = 0
      ..[18] = 0x0a
      ..[19] = 0xc4
      ..[20] = 0x42
      ..[21] = (totalSamples >> 32) & 0x0f
      ..[22] = (totalSamples >> 24) & 0xff
      ..[23] = (totalSamples >> 16) & 0xff
      ..[24] = (totalSamples >> 8) & 0xff
      ..[25] = totalSamples & 0xff;
    await File('${directory.path}/album.flac').writeAsBytes(flac);
    final cue = File('${directory.path}/album.cue');
    await cue.writeAsString('''
PERFORMER "Artist"
TITLE "Album"
FILE "album.flac" WAVE
  TRACK 01 AUDIO
    TITLE "First"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Second"
    INDEX 01 03:30:00
''');

    final tracks = await CueParser().parse(cue);
    final scan = await LocalAudioScanner().scanDirectory(directory.path);

    expect(tracks, hasLength(2));
    expect(tracks.first.extra['cueStartMs'], 0);
    expect(tracks.first.extra['cueEndMs'], 210000);
    expect(tracks.first.duration, const Duration(minutes: 3, seconds: 30));
    expect(scan.tracks.map((track) => track.title), ['First', 'Second']);
    expect(scan.tracks.last.duration, const Duration(minutes: 1, seconds: 30));
    expect(scan.tracks.last.extra['cueEndMs'], 300000);
  });
}
