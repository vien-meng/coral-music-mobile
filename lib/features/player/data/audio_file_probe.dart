import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

final class AudioFileInfo {
  const AudioFileInfo({this.bitrate, this.sampleRate, this.format});

  final int? bitrate;
  final int? sampleRate;
  final String? format;
}

abstract interface class AudioFileProbe {
  Future<AudioFileInfo> probe(Uri uri);
}

final class NoopAudioFileProbe implements AudioFileProbe {
  const NoopAudioFileProbe();

  @override
  Future<AudioFileInfo> probe(Uri uri) async => const AudioFileInfo();
}

final class HttpAudioFileProbe implements AudioFileProbe {
  static const _probeBytes = 64 * 1024;

  @override
  Future<AudioFileInfo> probe(Uri uri) async {
    if (!{'http', 'https'}.contains(uri.scheme)) return const AudioFileInfo();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers
          .set(HttpHeaders.rangeHeader, 'bytes=0-${_probeBytes - 1}');
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        return const AudioFileInfo();
      }
      final iterator = StreamIterator<List<int>>(response);
      final bytes = BytesBuilder(copy: false);
      try {
        while (bytes.length < _probeBytes && await iterator.moveNext()) {
          final chunk = iterator.current;
          final remaining = _probeBytes - bytes.length;
          bytes.add(
              chunk.length <= remaining ? chunk : chunk.sublist(0, remaining));
        }
      } finally {
        await iterator.cancel();
      }
      return parseAudioFileHeader(
        bytes.takeBytes(),
        totalBytes: _totalAudioBytes(response),
      );
    } on Object {
      return const AudioFileInfo();
    } finally {
      client.close(force: true);
    }
  }
}

int? _totalAudioBytes(HttpClientResponse response) {
  final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
  final rangeMatch =
      contentRange == null ? null : RegExp(r'/(\d+)$').firstMatch(contentRange);
  final rangedTotal = rangeMatch == null ? null : int.tryParse(rangeMatch[1]!);
  if (rangedTotal != null && rangedTotal > 0) return rangedTotal;
  return response.statusCode == HttpStatus.ok && response.contentLength > 0
      ? response.contentLength
      : null;
}

AudioFileInfo parseAudioFileHeader(List<int> raw, {int? totalBytes}) {
  final bytes = Uint8List.fromList(raw);
  if (_matches(bytes, const [0x66, 0x4c, 0x61, 0x43])) {
    return _parseFlac(bytes, totalBytes: totalBytes);
  }
  if (_matches(bytes, const [0x4f, 0x67, 0x67, 0x53])) {
    return const AudioFileInfo(format: 'ogg');
  }
  if (bytes.length >= 8 &&
      _matches(bytes.sublist(4), const [0x66, 0x74, 0x79, 0x70])) {
    return const AudioFileInfo(format: 'm4a');
  }
  if (_matches(bytes, const [0x49, 0x44, 0x33]) ||
      (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0)) {
    return _parseMp3(bytes);
  }
  return const AudioFileInfo();
}

bool _matches(List<int> bytes, List<int> marker) =>
    bytes.length >= marker.length &&
    List.generate(marker.length, (index) => bytes[index] == marker[index])
        .every((matches) => matches);

AudioFileInfo _parseFlac(Uint8List bytes, {int? totalBytes}) {
  if (bytes.length < 38 || (bytes[4] & 0x7f) != 0) {
    return const AudioFileInfo(format: 'flac');
  }
  final sampleRate =
      (bytes[18] << 12) | (bytes[19] << 4) | ((bytes[20] >> 4) & 0x0f);
  final totalSamples = ((bytes[21] & 0x0f) << 32) |
      (bytes[22] << 24) |
      (bytes[23] << 16) |
      (bytes[24] << 8) |
      bytes[25];
  final averageBitrate =
      totalBytes != null && totalBytes > 0 && totalSamples > 0
          ? (totalBytes * 8 * sampleRate / totalSamples).round()
          : null;
  return AudioFileInfo(
    sampleRate: sampleRate == 0 ? null : sampleRate,
    bitrate: averageBitrate,
    format: 'flac',
  );
}

AudioFileInfo _parseMp3(Uint8List bytes) {
  var offset = 0;
  if (_matches(bytes, const [0x49, 0x44, 0x33]) && bytes.length >= 10) {
    offset = 10 +
        (((bytes[6] & 0x7f) << 21) |
            ((bytes[7] & 0x7f) << 14) |
            ((bytes[8] & 0x7f) << 7) |
            (bytes[9] & 0x7f));
  }
  const mpeg1Bitrates = [
    [0],
    [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
    [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384],
    [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
  ];
  const mpeg2Bitrates = [
    [0],
    [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
    [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
    [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
  ];
  const rates = [
    [11025, 12000, 8000],
    [0, 0, 0],
    [22050, 24000, 16000],
    [44100, 48000, 32000],
  ];
  final end = (offset + 8192).clamp(0, bytes.length - 4);
  for (var index = offset; index < end; index++) {
    if (bytes[index] != 0xff || bytes[index + 1] & 0xe0 != 0xe0) continue;
    final version = (bytes[index + 1] >> 3) & 3;
    final layer = (bytes[index + 1] >> 1) & 3;
    final bitrateIndex = (bytes[index + 2] >> 4) & 15;
    final rateIndex = (bytes[index + 2] >> 2) & 3;
    if (version == 1 || layer == 0 || bitrateIndex == 0 || rateIndex == 3) {
      continue;
    }
    final sampleRate = rates[version][rateIndex];
    if (sampleRate == 0) continue;
    final bitrate =
        (version == 3 ? mpeg1Bitrates : mpeg2Bitrates)[layer][bitrateIndex];
    if (bitrate == 0) continue;
    return AudioFileInfo(
      bitrate: bitrate * 1000,
      sampleRate: sampleRate,
      format: 'mp3',
    );
  }
  return const AudioFileInfo(format: 'mp3');
}
