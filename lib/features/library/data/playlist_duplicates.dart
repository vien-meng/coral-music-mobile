import '../../../domain/music.dart';

Set<String> findDuplicateTrackIds(Iterable<Track> tracks) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final track in tracks) {
    final duration = track.duration?.inSeconds;
    if (duration == null) continue;
    final key = [track.title, track.artist, track.album ?? '']
        .map(_normalize)
        .followedBy(['$duration']).join('\n');
    if (!seen.add(key)) duplicates.add(track.id);
  }
  return duplicates;
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
