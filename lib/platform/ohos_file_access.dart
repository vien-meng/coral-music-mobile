import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

final class OhosFileAccess {
  OhosFileAccess._();
  static const _channel = MethodChannel('coral_music/file_access');
  static bool get isOhos => Platform.operatingSystem == 'ohos';
  static Future<List<String>> pickAudio() =>
      isOhos ? _pick('pickAudio', true) : _fallbackAudio();
  static Future<List<String>> pickDocuments(List<String> extensions) => isOhos
      ? _pick('pickDocuments', false, extensions)
      : _fallbackDocuments(extensions);

  static Future<bool> saveTextDocument({
    required String content,
    required String fileName,
    required List<String> extensions,
  }) async {
    if (isOhos) {
      return await _channel.invokeMethod<bool>('saveDocument', {
            'content': content,
            'fileName': fileName,
            'extensions': extensions,
          }) ??
          false;
    }
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '保存文件',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (path == null) return false;
    await File(path).writeAsString(content, flush: true);
    return true;
  }

  static Future<bool> exportFile({
    required String sourcePath,
    required String fileName,
  }) async {
    if (!isOhos) return false;
    return await _channel.invokeMethod<bool>('exportFile', {
          'sourcePath': sourcePath,
          'fileName': fileName,
        }) ??
        false;
  }

  static Future<Directory> applicationDocumentsDirectory() async {
    if (!isOhos) return getApplicationDocumentsDirectory();
    return Directory(await _applicationPath());
  }

  static Future<Directory> applicationSupportDirectory() async {
    if (!isOhos) return getApplicationSupportDirectory();
    return Directory(await _applicationPath());
  }

  static Future<String> _applicationPath() async {
    final path =
        await _channel.invokeMethod<String>('applicationDocumentsPath');
    if (path == null || path.isEmpty) {
      throw const FileSystemException('鸿蒙应用目录不可用');
    }
    return path;
  }

  static Future<List<String>> _pick(String method, bool multiple,
      [List<String>? extensions]) async {
    final values = await _channel.invokeListMethod<String>(method, {
      'multiple': multiple,
      if (extensions != null) 'extensions': extensions
    });
    return values?.map((value) {
          final uri = Uri.tryParse(value);
          return uri?.scheme == 'file' ? uri!.toFilePath() : value;
        }).toList() ??
        const [];
  }

  static Future<List<String>> _fallbackAudio() async =>
      (await FilePicker.platform
              .pickFiles(type: FileType.audio, allowMultiple: true))
          ?.paths
          .whereType<String>()
          .toList() ??
      const [];
  static Future<List<String>> _fallbackDocuments(
          List<String> extensions) async =>
      (await FilePicker.platform
              .pickFiles(type: FileType.custom, allowedExtensions: extensions))
          ?.paths
          .whereType<String>()
          .toList() ??
      const [];
}
