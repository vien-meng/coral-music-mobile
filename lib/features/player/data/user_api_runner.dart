import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';

final class UserApiManifest {
  const UserApiManifest(this.musicUrlSources, {this.lyricSources = const {}});

  final Set<String> musicUrlSources;
  final Set<String> lyricSources;
}

abstract interface class UserApiRunner {
  Future<UserApiManifest> load(String script);
  Future<void> clear();
  Future<Uri> resolveMusicUrl(Track track, AudioQuality quality);
  Future<LyricPayload?> resolveLyric(Track track);
}

final class MethodChannelUserApiRunner implements UserApiRunner {
  static const _channel = MethodChannel('coral_music/user_api');
  static const _scriptLimit = 256 * 1024;

  UserApiManifest? _manifest;

  @override
  Future<UserApiManifest> load(String script) async {
    if (script.isEmpty || script.length > _scriptLimit) {
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
      final lyricSources =
          (result?['lyricSources'] as List<Object?>? ?? const <Object?>[])
              .whereType<String>()
              .toSet();
      if (sources.isEmpty) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: '音源脚本未声明可用的 musicUrl 来源',
        );
      }
      return _manifest = UserApiManifest(sources, lyricSources: lyricSources);
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
  Future<Uri> resolveMusicUrl(Track track, AudioQuality quality) async {
    final manifest = _manifest;
    if (manifest == null ||
        !manifest.musicUrlSources.contains(track.sourceId)) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '当前音源未支持该歌曲来源',
      );
    }
    try {
      final value = await _channel.invokeMethod<String>('resolveMusicUrl', {
        'source': track.sourceId,
        'quality': _qualityName(quality),
        'musicInfo': _legacyMusicInfo(track),
      });
      final uri = Uri.tryParse(value ?? '');
      if (uri == null || uri.scheme != 'https' || value!.length > 8192) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: '音源未返回安全的 HTTPS 播放地址',
        );
      }
      return uri;
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

  @override
  Future<LyricPayload?> resolveLyric(Track track) async {
    final manifest = _manifest;
    if (manifest == null || !manifest.lyricSources.contains(track.sourceId)) {
      return null;
    }
    try {
      final raw = await _channel.invokeMethod<String>('resolveLyric', {
        'source': track.sourceId,
        'musicInfo': _legacyMusicInfo(track),
      });
      if (raw == null || raw.length > 256 * 1024) {
        throw const AppFailure(
          code: AppFailureCode.invalidData,
          message: '音源未返回有效歌词',
        );
      }
      final value = jsonDecode(raw);
      final data = value is Map<String, dynamic> && value['data'] is Map
          ? value['data'] as Map<Object?, Object?>
          : value is Map
              ? value
              : <Object?, Object?>{'lyric': value};
      return LyricPayload(
        lyric: data['lyric'] as String? ?? '',
        lxlyric: data['lxlyric'] as String? ?? '',
        tlyric: data['tlyric'] as String? ?? '',
        rlyric: data['rlyric'] as String? ?? '',
      );
    } on PlatformException catch (error) {
      throw AppFailure(
        code: AppFailureCode.invalidData,
        message: error.message ?? '音源歌词获取失败',
        diagnostic: error.code,
      );
    } on FormatException {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '音源未返回有效歌词',
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

  static Map<String, Object?> _legacyMusicInfo(Track track) => {
        'source': track.sourceId,
        'songmid': track.sourceTrackId,
        'name': track.title,
        'singer': track.artist,
        'albumName': track.album ?? '',
        'albumId': track.extra['albumId'],
        'albumMid': track.extra['albumMid'],
        'songId': track.extra['songId'],
        'strMediaMid': track.extra['mediaMid'],
      };
}
