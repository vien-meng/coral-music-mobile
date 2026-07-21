import 'package:flutter/services.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';

final class UserApiManifest {
  const UserApiManifest(this.musicUrlSources);

  final Set<String> musicUrlSources;
}

final class ResolvedPlaybackUrl {
  const ResolvedPlaybackUrl(this.uri, {this.quality, this.headers = const {}});

  final Uri uri;
  final AudioQuality? quality;
  final Map<String, String> headers;
}

abstract interface class UserApiRunner {
  Future<UserApiManifest> load(String script);
  Future<void> clear();
  Future<ResolvedPlaybackUrl> resolveMusicUrl(
      Track track, AudioQuality quality);
}

final class MethodChannelUserApiRunner implements UserApiRunner {
  static const _channel = MethodChannel('coral_music/user_api');
  static const _scriptLimit = 256 * 1024;

  UserApiManifest? _manifest;

  @override
  Future<UserApiManifest> load(String script) async {
    if (script.trim().isEmpty || script.length > _scriptLimit) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '音源脚本为空或超过大小限制',
      );
    }
    try {
      final result = await _channel
          .invokeMapMethod<String, Object?>('load', {'script': script});
      final sources =
          (result?['musicUrlSources'] as List<Object?>? ?? const <Object?>[])
              .whereType<String>()
              .toSet();
      if (sources.isEmpty) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: '音源脚本未声明可用的 musicUrl 来源',
        );
      }
      return _manifest = UserApiManifest(sources);
    } on PlatformException catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: error.message ?? '音源脚本加载失败',
        diagnostic: error.code,
      );
    } on MissingPluginException {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '当前平台尚未验证受限音源脚本运行时',
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
      _manifest = null;
    } on PlatformException catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: error.message ?? '音源脚本清理失败',
        diagnostic: error.code,
      );
    } on MissingPluginException {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '当前平台尚未验证受限音源脚本运行时',
      );
    }
  }

  @override
  Future<ResolvedPlaybackUrl> resolveMusicUrl(
    Track track,
    AudioQuality quality,
  ) async {
    final manifest = _manifest;
    if (manifest == null) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '请先在音源管理导入并启用音源，再播放在线歌曲',
      );
    }
    if (!manifest.musicUrlSources.contains(track.sourceId)) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '当前音源未支持该歌曲来源',
      );
    }
    try {
      final value = await _channel.invokeMethod<Object?>('resolveMusicUrl', {
        'source': track.sourceId,
        'quality': _qualityName(quality),
        'musicInfo': _legacyMusicInfo(track),
      });
      final map = value is Map ? value : null;
      final url = value is String ? value : map?['url'] as String?;
      final uri = Uri.tryParse(url ?? '');
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          url == null ||
          url.length > 8192) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: '音源未返回有效的 HTTP 播放地址',
        );
      }
      return ResolvedPlaybackUrl(
        uri,
        quality: _qualityFromName(map?['type'] as String?),
      );
    } on PlatformException catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: error.message ?? '音源取链失败',
        diagnostic: error.code,
      );
    } on MissingPluginException {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '当前平台尚未验证受限音源脚本运行时',
      );
    }
  }

  static String _qualityName(AudioQuality quality) => switch (quality) {
        AudioQuality.flac24bit => 'flac24bit',
        AudioQuality.flac => 'flac',
        AudioQuality.high320k => '320k',
        AudioQuality.high192k => '192k',
        AudioQuality.standard128k => '128k',
        AudioQuality.hires => 'hires',
        AudioQuality.atmos => 'atmos',
        AudioQuality.atmosPlus => 'atmos_plus',
        AudioQuality.master => 'master',
      };

  static AudioQuality? _qualityFromName(String? value) => switch (value) {
        'flac24bit' => AudioQuality.flac24bit,
        'flac' => AudioQuality.flac,
        '320k' => AudioQuality.high320k,
        '192k' => AudioQuality.high192k,
        '128k' => AudioQuality.standard128k,
        'hires' => AudioQuality.hires,
        'atmos' => AudioQuality.atmos,
        'atmos_plus' => AudioQuality.atmosPlus,
        'master' => AudioQuality.master,
        _ => null,
      };

  static Map<String, Object?> _legacyMusicInfo(Track track) {
    final songId = track.extra['songId'] ?? track.sourceTrackId;
    final qualityMeta = track.extra['qualityMeta'];
    Map<String, Object?> metadataFor(AudioQuality quality) {
      final raw =
          qualityMeta is Map ? qualityMeta[_qualityName(quality)] : null;
      if (raw is! Map) return const {'size': null};
      return {
        'size': raw['size'],
        if (raw['hash'] != null) 'hash': raw['hash'],
      };
    }

    final qualities = [
      for (final quality in track.availableQualities)
        {'type': _qualityName(quality), ...metadataFor(quality)},
    ];
    final qualitys = {
      for (final quality in track.availableQualities)
        _qualityName(quality): metadataFor(quality),
    };
    final lrcUrl = track.extra['lrcUrl'];
    final mrcUrl = track.extra['mrcUrl'];
    final trcUrl = track.extra['trcUrl'];

    final meta = <String, Object?>{
      'songId': songId,
      'albumName': track.album ?? '',
      'picUrl': track.coverUri?.toString(),
      'albumId': track.extra['albumId'],
      'albumMid': track.extra['albumMid'],
      'strMediaMid': track.extra['mediaMid'],
      'hash': track.extra['hash'],
      'copyrightId': track.extra['copyrightId'] ?? songId,
      'qualitys': qualities,
      '_qualitys': qualitys,
    };
    return {
      // Desktop User API scripts consume this MusicInfo shape.
      'id': track.sourceTrackId,
      'name': track.title,
      'singer': track.artist,
      'source': track.sourceId,
      'interval': _formatInterval(track.duration),
      'meta': meta,
      // These fields keep compatibility with older scripts that predate meta.
      'songmid': track.sourceTrackId,
      'albumName': track.album ?? '',
      'img': track.coverUri?.toString() ?? '',
      'typeUrl': const <String, Object?>{},
      'albumId': meta['albumId'],
      'albumMid': meta['albumMid'],
      'songId': songId,
      'strMediaMid': meta['strMediaMid'],
      'copyrightId': meta['copyrightId'],
      'lrcUrl': lrcUrl,
      'mrcUrl': mrcUrl,
      'trcUrl': trcUrl,
      'types': qualities,
      '_types': qualitys,
    };
  }

  static String? _formatInterval(Duration? duration) {
    if (duration == null) return null;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
