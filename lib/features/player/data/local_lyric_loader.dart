import 'dart:convert';
import 'dart:io';

import '../../../domain/music.dart';

final class LocalLyricLoader {
  static const _limit = 512 * 1024;

  Future<LyricPayload?> load(Track track) async {
    final uri = track.localUri;
    if (uri == null || uri.scheme != 'file') return null;
    final musicFile = File.fromUri(uri);
    final directory = musicFile.parent;
    final baseName =
        musicFile.uri.pathSegments.last.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final names = <String>{
      baseName,
      '${_safe(track.artist)} - ${_safe(track.title)}',
      '${_safe(track.title)} - ${_safe(track.artist)}',
      _safe(track.title),
    };
    for (final name in names) {
      final file = File('${directory.path}${Platform.pathSeparator}$name.lrc');
      try {
        if (!await file.exists() || await file.length() > _limit) continue;
        return LyricPayload(lyric: utf8.decode(await file.readAsBytes()));
      } on FileSystemException {
        continue;
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  String _safe(String value) => value.replaceAll(RegExp(r'[\\/]'), '_');
}
