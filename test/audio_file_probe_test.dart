import 'package:coral_music_mobile/features/player/data/audio_file_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses FLAC streaminfo for actual file details', () {
    final bytes = List<int>.filled(38, 0)
      ..setRange(0, 4, 'fLaC'.codeUnits)
      ..[4] = 0
      ..[18] = 0x0a
      ..[19] = 0xc4
      ..[20] = 0x42
      ..[21] = 0xf0;

    final info = parseAudioFileHeader(bytes);

    expect(info.format, 'flac');
    expect(info.sampleRate, 44100);
    expect(info.bitrate, 1411200);
  });

  test('parses a MPEG1 Layer III frame header', () {
    final info = parseAudioFileHeader([0xff, 0xfb, 0x90, 0x00, 0, 0]);

    expect(info.format, 'mp3');
    expect(info.sampleRate, 44100);
    expect(info.bitrate, 128000);
  });
}
