import '../domain/music.dart';

String audioQualityLabel(AudioQuality quality) => switch (quality) {
      AudioQuality.master => '臻品母带',
      AudioQuality.atmosPlus => '臻品全景声',
      AudioQuality.atmos => '全景声',
      AudioQuality.hires => 'Hi-Res',
      AudioQuality.flac24bit => 'Hi-Res 24bit',
      AudioQuality.flac => 'SQ',
      AudioQuality.high320k => 'HQ',
      AudioQuality.high192k => '192k',
      AudioQuality.standard128k => '128k',
    };

String audioQualityDescription(AudioQuality quality) => switch (quality) {
      AudioQuality.master => '母带级音质',
      AudioQuality.atmosPlus => '臻品全景声',
      AudioQuality.atmos => '沉浸式全景声',
      AudioQuality.hires => '高解析度音频',
      AudioQuality.flac24bit => '24 bit 无损音频',
      AudioQuality.flac => 'FLAC 无损音频',
      AudioQuality.high320k => '320 kbps 高品质',
      AudioQuality.high192k => '192 kbps 高品质',
      AudioQuality.standard128k => '128 kbps 标准音质',
    };
