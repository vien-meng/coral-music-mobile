import 'package:flutter/services.dart';

final class LocalAudioDirectoryAccess {
  static const _channel = MethodChannel('coral_music/local_audio');

  static Future<bool> ensure() async {
    try {
      return await _channel.invokeMethod<bool>('ensureDirectoryReadAccess') ??
          false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }
}
