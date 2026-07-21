import 'package:coral_music_mobile/features/player/data/audio_file_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not invent a FLAC bitrate without complete file metadata', () {
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
    expect(info.bitrate, isNull);
  });

  test('uses the FLAC file size and total samples for average bitrate', () {
    final bytes = List<int>.filled(38, 0)
      ..setRange(0, 4, 'fLaC'.codeUnits)
      ..[4] = 0
      ..[18] = 0x0a
      ..[19] = 0xc4
      ..[20] = 0x42
      ..[21] = 0xf0
      ..[22] = 0x00
      ..[23] = 0x01
      ..[24] = 0x58
      ..[25] = 0x88;

    final info = parseAudioFileHeader(bytes, totalBytes: 220500);

    expect(info.sampleRate, 44100);
    expect(info.bitrate, 882000);
    expect(info.duration, const Duration(seconds: 2));
  });

  test('parses a MPEG1 Layer III frame header', () {
    final info = parseAudioFileHeader([0xff, 0xfb, 0x90, 0x00, 0, 0]);

    expect(info.format, 'mp3');
    expect(info.sampleRate, 44100);
    expect(info.bitrate, 128000);
  });

  test('parses the raw DSD stream properties from a DSF header', () {
    final bytes = List<int>.filled(96, 0)
      ..setRange(0, 4, 'DSD '.codeUnits)
      ..setRange(28, 32, 'fmt '.codeUnits)
      ..[52] = 2
      ..[56] = 0
      ..[57] = 0x11
      ..[58] = 0x2b;

    final info = parseAudioFileHeader(bytes);

    expect(info.format, 'dsf');
    expect(info.sampleRate, 2822400);
    expect(info.bitrate, 5644800);
  });

  test('parses the raw DSD stream properties from a DFF PROP chunk', () {
    final bytes = List<int>.filled(80, 0)
      ..setRange(0, 4, 'FRM8'.codeUnits)
      ..setRange(12, 16, 'DSD '.codeUnits)
      ..setRange(16, 20, 'PROP'.codeUnits)
      ..[27] = 36
      ..setRange(28, 32, 'SND '.codeUnits)
      ..setRange(32, 36, 'FS  '.codeUnits)
      ..[43] = 4
      ..[44] = 0
      ..[45] = 0x2b
      ..[46] = 0x11
      ..[47] = 0x00
      ..setRange(48, 52, 'CHNL'.codeUnits)
      ..[59] = 2
      ..[60] = 0
      ..[61] = 2;

    final info = parseAudioFileHeader(bytes);

    expect(info.format, 'dff');
    expect(info.sampleRate, 2822400);
    expect(info.bitrate, 5644800);
  });

  test('uses WAV byte rate and flags a DTS stream in a WAV container', () {
    final bytes = List<int>.filled(64, 0)
      ..setRange(0, 4, 'RIFF'.codeUnits)
      ..setRange(8, 12, 'WAVE'.codeUnits)
      ..setRange(12, 16, 'fmt '.codeUnits)
      ..[16] = 16
      ..[20] = 1
      ..[22] = 2
      ..[24] = 0x44
      ..[25] = 0xac
      ..[28] = 0x10
      ..[29] = 0xb1
      ..[30] = 2
      ..setRange(36, 40, 'data'.codeUnits)
      ..setRange(44, 48, const [0x7f, 0xfe, 0x80, 0x01]);

    final info = parseAudioFileHeader(bytes);

    expect(info.format, 'dts');
    expect(info.sampleRate, 44100);
    expect(info.bitrate, 1411200);
  });
}
