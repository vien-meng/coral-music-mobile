import 'package:flutter/services.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';

final class KuwoLyricService {
  static const _channel = MethodChannel('coral_music/user_api');

  Future<LyricPayload?> resolve(Track track) async {
    if (track.sourceId != OnlineSource.kuwo.id) return null;
    try {
      final lyric = await _channel.invokeMethod<String>(
        'resolveKuwoLyric',
        {'songId': track.sourceTrackId},
      );
      return lyric == null || lyric.isEmpty ? null : LyricPayload(lyric: lyric);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: error.message ?? '酷我歌词加载失败',
        diagnostic: error.code,
      );
    }
  }
}
