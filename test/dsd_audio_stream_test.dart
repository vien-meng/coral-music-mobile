import 'dart:io';

import 'package:coral_music_mobile/features/player/data/dsd_audio_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects DSF/DFF and detects DTS frames separately', () {
    expect(isDsdAudioUri(Uri.file('/music/demo.DSF')), isTrue);
    expect(isDsdAudioUri(Uri.file('/music/demo.dff')), isTrue);
    expect(isDsdAudioUri(Uri.file('/music/demo.flac')), isFalse);
    expect(isFfmpegStreamUri(Uri.file('/music/demo.wav')), isFalse);
    expect(isFfmpegStreamUri(Uri.file('/music/demo.flac')), isFalse);
    expect(isDsdAudioUri(Uri.parse('https://example.com/demo.dsf')), isFalse);
    expect(containsDtsFrameSync(const [0, 0x7f, 0xfe, 0x80, 1]), isTrue);
    expect(containsDtsFrameSync(const [0, 1, 2, 3, 4]), isFalse);
  });

  test('relocates stale iOS Documents URIs after an app reinstall', () {
    final relocated = relocateIosSandboxDocumentUri(
      Uri.file(
          '/private/var/mobile/Containers/Data/Application/old/Documents/music/demo.flac'),
      Directory(
          '/private/var/mobile/Containers/Data/Application/new/Documents'),
    );

    expect(
      relocated,
      Uri.file(
          '/private/var/mobile/Containers/Data/Application/new/Documents/music/demo.flac'),
    );
    expect(
        relocateIosSandboxDocumentUri(
            Uri.parse('https://example.com/demo.flac'), Directory('/tmp')),
        isNull);
  });
}
