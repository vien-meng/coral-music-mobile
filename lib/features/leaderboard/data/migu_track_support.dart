import '../../../domain/music.dart';

List<AudioQuality> miguAudioQualities(Object? raw) {
  final available = <AudioQuality>{};
  if (raw is List) {
    for (final item in raw.whereType<Map>()) {
      switch (item['formatType']) {
        case 'PQ':
          available.add(AudioQuality.standard128k);
        case 'HQ':
          available.add(AudioQuality.high320k);
        case 'SQ':
          available.add(AudioQuality.flac);
        case 'ZQ' || 'ZQ24':
          available.add(AudioQuality.flac24bit);
      }
    }
  }
  return AudioQuality.values.where(available.contains).toList(growable: false);
}

Map<String, Object?> miguQualityMeta(Object? raw) {
  if (raw is! List) return const {};
  final values = <String, Object?>{};
  for (final item in raw.whereType<Map>()) {
    final quality = switch (item['formatType']) {
      'PQ' => AudioQuality.standard128k,
      'HQ' => AudioQuality.high320k,
      'SQ' => AudioQuality.flac,
      'ZQ' || 'ZQ24' => AudioQuality.flac24bit,
      _ => null,
    };
    if (quality == null) continue;
    values[_wireQualityName(quality)] = {
      'size':
          item['asize'] ?? item['isize'] ?? item['size'] ?? item['androidSize'],
    };
  }
  return values;
}

String _wireQualityName(AudioQuality quality) => switch (quality) {
      AudioQuality.flac24bit => 'flac24bit',
      AudioQuality.flac => 'flac',
      AudioQuality.high320k => '320k',
      AudioQuality.standard128k => '128k',
      _ => quality.name,
    };
