import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

final class AudioFileInfo {
  const AudioFileInfo({
    this.bitrate,
    this.sampleRate,
    this.format,
    this.duration,
  });

  final int? bitrate;
  final int? sampleRate;
  final String? format;
  final Duration? duration;
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
    if (uri.scheme == 'file') return _probeLocalFile(uri);
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

  Future<AudioFileInfo> _probeLocalFile(Uri uri) async {
    try {
      final file = File.fromUri(uri);
      final totalBytes = await file.length();
      final bytes = await file.openRead(0, _probeBytes).fold<BytesBuilder>(
          BytesBuilder(copy: false), (buffer, chunk) => buffer..add(chunk));
      return parseAudioFileHeader(bytes.takeBytes(), totalBytes: totalBytes);
    } on Object {
      return const AudioFileInfo();
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
  if (_matches(bytes, const [0x44, 0x53, 0x44, 0x20])) {
    return _parseDsf(bytes);
  }
  if (_matches(bytes, const [0x46, 0x52, 0x4d, 0x38])) {
    return _parseDff(bytes);
  }
  if (_matches(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
      _matchesAt(bytes, 8, const [0x57, 0x41, 0x56, 0x45])) {
    return _parseWav(bytes);
  }
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
    return _parseMp3(bytes, totalBytes: totalBytes);
  }
  return const AudioFileInfo();
}

bool _matches(List<int> bytes, List<int> marker) =>
    bytes.length >= marker.length &&
    List.generate(marker.length, (index) => bytes[index] == marker[index])
        .every((matches) => matches);

bool _matchesAt(List<int> bytes, int offset, List<int> marker) =>
    offset >= 0 &&
    bytes.length >= offset + marker.length &&
    List.generate(
            marker.length, (index) => bytes[offset + index] == marker[index])
        .every((matches) => matches);

AudioFileInfo _parseDsf(Uint8List bytes) {
  const formatOffset = 28;
  if (!_matchesAt(bytes, formatOffset, const [0x66, 0x6d, 0x74, 0x20])) {
    return const AudioFileInfo(format: 'dsf');
  }
  final channels = _u32Le(bytes, formatOffset + 24);
  final sampleRate = _u32Le(bytes, formatOffset + 28);
  if (channels == null ||
      channels == 0 ||
      sampleRate == null ||
      sampleRate == 0) {
    return const AudioFileInfo(format: 'dsf');
  }
  return AudioFileInfo(
    format: 'dsf',
    sampleRate: sampleRate,
    bitrate: sampleRate * channels,
  );
}

AudioFileInfo _parseDff(Uint8List bytes) {
  if (!_matchesAt(bytes, 12, const [0x44, 0x53, 0x44, 0x20])) {
    return const AudioFileInfo(format: 'dff');
  }
  var offset = 16;
  while (offset + 12 <= bytes.length) {
    final chunkLength = _u64Be(bytes, offset + 4);
    if (chunkLength == null) break;
    final dataOffset = offset + 12;
    if (_matchesAt(bytes, offset, const [0x50, 0x52, 0x4f, 0x50]) &&
        _matchesAt(bytes, dataOffset, const [0x53, 0x4e, 0x44, 0x20])) {
      return _parseDffSoundProperties(bytes, dataOffset + 4, chunkLength - 4);
    }
    final nextOffset = dataOffset + chunkLength + (chunkLength.isOdd ? 1 : 0);
    if (nextOffset <= offset || nextOffset > bytes.length) break;
    offset = nextOffset;
  }
  return const AudioFileInfo(format: 'dff');
}

AudioFileInfo _parseDffSoundProperties(
  Uint8List bytes,
  int offset,
  int availableBytes,
) {
  final end = (offset + availableBytes).clamp(0, bytes.length);
  int? sampleRate;
  int? channels;
  while (offset + 12 <= end) {
    final chunkLength = _u64Be(bytes, offset + 4);
    if (chunkLength == null) break;
    final dataOffset = offset + 12;
    if (dataOffset + chunkLength > end) break;
    if (_matchesAt(bytes, offset, const [0x46, 0x53, 0x20, 0x20])) {
      sampleRate = _u32Be(bytes, dataOffset);
    } else if (_matchesAt(bytes, offset, const [0x43, 0x48, 0x4e, 0x4c])) {
      channels = _u16Be(bytes, dataOffset);
    }
    if (sampleRate != null &&
        sampleRate > 0 &&
        channels != null &&
        channels > 0) {
      return AudioFileInfo(
        format: 'dff',
        sampleRate: sampleRate,
        bitrate: sampleRate * channels,
      );
    }
    final nextOffset = dataOffset + chunkLength + (chunkLength.isOdd ? 1 : 0);
    if (nextOffset <= offset) break;
    offset = nextOffset;
  }
  return const AudioFileInfo(format: 'dff');
}

AudioFileInfo _parseWav(Uint8List bytes) {
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkLength = _u32Le(bytes, offset + 4);
    if (chunkLength == null) break;
    final dataOffset = offset + 8;
    if (_matchesAt(bytes, offset, const [0x66, 0x6d, 0x74, 0x20])) {
      if (chunkLength < 16 || dataOffset + 16 > bytes.length) {
        return const AudioFileInfo(format: 'wav');
      }
      final sampleRate = _u32Le(bytes, dataOffset + 4);
      final byteRate = _u32Le(bytes, dataOffset + 8);
      final isDts = _containsDtsFrameSync(bytes);
      return AudioFileInfo(
        format: isDts ? 'dts' : 'wav',
        sampleRate: sampleRate == 0 ? null : sampleRate,
        bitrate: byteRate == 0 ? null : byteRate! * 8,
      );
    }
    final nextOffset = dataOffset + chunkLength + (chunkLength.isOdd ? 1 : 0);
    if (nextOffset <= offset || nextOffset > bytes.length) break;
    offset = nextOffset;
  }
  return const AudioFileInfo(format: 'wav');
}

bool _containsDtsFrameSync(Uint8List bytes) {
  const syncWords = [
    [0x7f, 0xfe, 0x80, 0x01],
    [0xfe, 0x7f, 0x01, 0x80],
    [0x1f, 0xff, 0xe8, 0x00],
    [0xff, 0x1f, 0x00, 0xe8],
  ];
  for (var offset = 0; offset <= bytes.length - 4; offset++) {
    if (syncWords.any((sync) => _matchesAt(bytes, offset, sync))) return true;
  }
  return false;
}

int? _u16Be(Uint8List bytes, int offset) =>
    offset < 0 || offset + 2 > bytes.length
        ? null
        : (bytes[offset] << 8) | bytes[offset + 1];

int? _u32Le(Uint8List bytes, int offset) =>
    offset < 0 || offset + 4 > bytes.length
        ? null
        : bytes[offset] |
            (bytes[offset + 1] << 8) |
            (bytes[offset + 2] << 16) |
            (bytes[offset + 3] << 24);

int? _u32Be(Uint8List bytes, int offset) =>
    offset < 0 || offset + 4 > bytes.length
        ? null
        : (bytes[offset] << 24) |
            (bytes[offset + 1] << 16) |
            (bytes[offset + 2] << 8) |
            bytes[offset + 3];

int? _u64Be(Uint8List bytes, int offset) {
  if (offset < 0 || offset + 8 > bytes.length) return null;
  var value = 0;
  for (var index = offset; index < offset + 8; index++) {
    value = (value << 8) | bytes[index];
  }
  return value;
}

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
    duration: sampleRate == 0 || totalSamples == 0
        ? null
        : Duration(
            microseconds:
                totalSamples * Duration.microsecondsPerSecond ~/ sampleRate,
          ),
  );
}

AudioFileInfo _parseMp3(Uint8List bytes, {int? totalBytes}) {
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
      duration: totalBytes == null || totalBytes <= 0
          ? null
          : Duration(
              microseconds: totalBytes *
                  8 *
                  Duration.microsecondsPerSecond ~/
                  (bitrate * 1000),
            ),
    );
  }
  return const AudioFileInfo(format: 'mp3');
}
