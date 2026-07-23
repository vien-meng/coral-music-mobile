import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_session.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

bool isDsdAudioUri(Uri uri) {
  if (uri.scheme != 'file') return false;
  final extension = uri.path.split('.').last.toLowerCase();
  return extension == 'dsf' || extension == 'dff';
}

bool isFfmpegStreamUri(Uri uri) {
  if (uri.scheme != 'file') return false;
  final extension = uri.path.split('.').last.toLowerCase();
  return extension == 'dsf' || extension == 'dff';
}

Uri? relocateIosSandboxDocumentUri(Uri uri, Directory documentsDirectory) {
  if (uri.scheme != 'file') return null;
  const documentsMarker = '/Documents/';
  final offset = uri.path.indexOf(documentsMarker);
  if (offset < 0) return null;
  final relativePath = uri.path.substring(offset + documentsMarker.length);
  if (relativePath.isEmpty) return null;
  return Uri.file('${documentsDirectory.path}/$relativePath');
}

Future<Uri> recoverIosSandboxDocumentUri(Uri uri) async {
  if (!Platform.isIOS ||
      uri.scheme != 'file' ||
      await File.fromUri(uri).exists()) {
    return uri;
  }
  final relocated = relocateIosSandboxDocumentUri(
      uri, await getApplicationDocumentsDirectory());
  return relocated != null && await File.fromUri(relocated).exists()
      ? relocated
      : uri;
}

bool containsDtsFrameSync(List<int> bytes) {
  const syncWords = [
    [0x7f, 0xfe, 0x80, 0x01],
    [0xfe, 0x7f, 0x01, 0x80],
    [0x1f, 0xff, 0xe8, 0x00],
    [0xff, 0x1f, 0x00, 0xe8],
  ];
  for (var offset = 0; offset <= bytes.length - 4; offset++) {
    if (syncWords.any((sync) =>
        bytes[offset] == sync[0] &&
        bytes[offset + 1] == sync[1] &&
        bytes[offset + 2] == sync[2] &&
        bytes[offset + 3] == sync[3])) {
      return true;
    }
  }
  return false;
}

/// Normalizes local DSD and WAV files to a temporary PCM WAV source.
final class FfmpegAudioStream {
  FfmpegAudioStream._(this.uri, this._output);

  final Uri uri;
  final File _output;

  static Future<FfmpegAudioStream?> open(Uri input) async {
    final isDsd = isDsdAudioUri(input);
    if (!isDsd && !await _isDtsWav(input)) return null;
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('DSF/DFF/DTS-WAV 规范化播放当前不受此平台支持');
    }

    final directory = await getTemporaryDirectory();
    final output = File(
      '${directory.path}/coral-ffmpeg-${Random.secure().nextInt(1 << 32)}.wav',
    );
    try {
      final completion = Completer<FFmpegSession>();
      await FFmpegKit.executeWithArgumentsAsync([
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-threads',
        '1',
        if (isDsd && input.path.toLowerCase().endsWith('.dff')) ...[
          '-f',
          'iff',
        ],
        '-i',
        input.toFilePath(),
        '-map',
        '0:a:0',
        '-vn',
        '-acodec',
        'pcm_s16le',
        // DTS-in-WAV may have 7 channels; stereo PCM is the portable output.
        '-ac',
        '2',
        if (isDsd) ...['-ar', '44100'],
        '-f',
        'wav',
        output.path,
      ], (session) => completion.complete(session));
      final session = await completion.future;
      if (!ReturnCode.isSuccess(await session.getReturnCode())) {
        if (kDebugMode) {
          debugPrint(
              'FFmpeg local decode failed: ${await session.getAllLogsAsString()}');
        }
        throw StateError('本地音频解码失败');
      }
      if (!await output.exists() || await output.length() == 0) {
        throw StateError('本地音频解码没有生成数据');
      }
      return FfmpegAudioStream._(output.uri, output);
    } on Object {
      try {
        await output.delete();
      } on FileSystemException {
        // The decoder may fail before creating its output file.
      }
      rethrow;
    }
  }

  static Future<bool> _isDtsWav(Uri input) async {
    if (input.scheme != 'file' || !input.path.toLowerCase().endsWith('.wav')) {
      return false;
    }
    try {
      final bytes = await File.fromUri(input)
          .openRead(0, 64 * 1024)
          .fold<BytesBuilder>(
              BytesBuilder(copy: false), (buffer, chunk) => buffer..add(chunk));
      return containsDtsFrameSync(bytes.takeBytes());
    } on FileSystemException {
      return false;
    }
  }

  Future<void> dispose() async {
    try {
      await _output.delete();
    } on FileSystemException {
      // The next track may already have removed the transient output.
    }
  }
}
