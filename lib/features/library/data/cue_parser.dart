import 'dart:io';

import '../../../domain/music.dart';

final class CueParser {
  Future<List<Track>> parse(File cue) async {
    final lines = await cue.readAsLines();
    var album = '';
    var albumArtist = '';
    String? audio;
    _CueTrack? current;
    final tracks = <_CueTrack>[];
    for (final raw in lines) {
      final line = raw.trim();
      final file = RegExp(r'^FILE\s+"?(.+?)"?\s+\w+', caseSensitive: false)
          .firstMatch(line);
      if (file != null) {
        audio = file.group(1)?.replaceAll('\\', Platform.pathSeparator);
        continue;
      }
      final title = _value(line, 'TITLE');
      final performer = _value(line, 'PERFORMER');
      final track =
          RegExp(r'^TRACK\s+(\d+)', caseSensitive: false).firstMatch(line);
      if (track != null) {
        if (current != null) tracks.add(current);
        current = _CueTrack(number: track.group(1)!, audio: audio);
        continue;
      }
      if (current == null) {
        album = title ?? album;
        albumArtist = performer ?? albumArtist;
        continue;
      }
      current
        ..title = title ?? current.title
        ..artist = performer ?? current.artist;
      final index =
          RegExp(r'^INDEX\s+01\s+(\d+):(\d+):(\d+)', caseSensitive: false)
              .firstMatch(line);
      if (index != null) {
        current.start = Duration(
          milliseconds:
              ((int.parse(index.group(1)!) * 60 + int.parse(index.group(2)!)) *
                      1000) +
                  (int.parse(index.group(3)!) * 1000 ~/ 75),
        );
      }
    }
    if (current != null) tracks.add(current);
    return [
      for (var index = 0; index < tracks.length; index++)
        if (tracks[index].audio != null && tracks[index].start != null)
          _toTrack(
            cue,
            tracks[index],
            album,
            albumArtist,
            index + 1 < tracks.length &&
                    tracks[index + 1].audio == tracks[index].audio
                ? tracks[index + 1].start
                : null,
          ),
    ];
  }

  String? _value(String line, String key) =>
      RegExp('^$key\\s+"?(.+?)"?\$', caseSensitive: false)
          .firstMatch(line)
          ?.group(1);

  Track _toTrack(
    File cue,
    _CueTrack cueTrack,
    String album,
    String albumArtist,
    Duration? end,
  ) {
    final media =
        File('${cue.parent.path}${Platform.pathSeparator}${cueTrack.audio}');
    return Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'device',
      sourceTrackId: '${media.absolute.path}#${cueTrack.number}',
      title: cueTrack.title.isEmpty ? '曲目 ${cueTrack.number}' : cueTrack.title,
      artist: cueTrack.artist.isEmpty ? albumArtist : cueTrack.artist,
      album: album.isEmpty ? null : album,
      duration: end == null ? null : end - cueTrack.start!,
      localUri: media.absolute.uri,
      extra: {
        'cueStartMs': cueTrack.start!.inMilliseconds,
        if (end != null) 'cueEndMs': end.inMilliseconds,
      },
    );
  }
}

final class _CueTrack {
  _CueTrack({required this.number, required this.audio});

  final String number;
  final String? audio;
  String title = '';
  String artist = '';
  Duration? start;
}
