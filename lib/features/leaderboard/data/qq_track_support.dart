import '../../../domain/music.dart';

List<AudioQuality> qqAudioQualities(Object? raw) {
  if (raw is! Map) return const [];
  final available = <AudioQuality>{};
  if (_positive(raw['size_hires'])) available.add(AudioQuality.flac24bit);
  if (_positive(raw['size_flac'])) available.add(AudioQuality.flac);
  if (_positive(raw['size_320mp3'])) available.add(AudioQuality.high320k);
  if (_positive(raw['size_128mp3'])) {
    available.add(AudioQuality.standard128k);
  }
  return AudioQuality.values.where(available.contains).toList(growable: false);
}

Map<String, Object?> qqQualityMeta(Object? raw) {
  if (raw is! Map) return const {};
  final values = <String, Object?>{};
  void add(AudioQuality quality, Object? size) {
    if (_positive(size)) values[_wireQualityName(quality)] = {'size': size};
  }

  add(AudioQuality.flac24bit, raw['size_hires']);
  add(AudioQuality.flac, raw['size_flac']);
  add(AudioQuality.high320k, raw['size_320mp3']);
  add(AudioQuality.standard128k, raw['size_128mp3']);
  return values;
}

bool _positive(Object? value) => (int.tryParse('$value') ?? 0) > 0;

String _wireQualityName(AudioQuality quality) => switch (quality) {
      AudioQuality.flac24bit => 'flac24bit',
      AudioQuality.flac => 'flac',
      AudioQuality.high320k => '320k',
      AudioQuality.standard128k => '128k',
      _ => quality.name,
    };
