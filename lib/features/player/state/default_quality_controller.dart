import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../domain/music.dart';

final defaultPlaybackQualityProvider =
    StateNotifierProvider<DefaultQualityController, AudioQuality>(
  (_) => DefaultQualityController(),
);

final class DefaultQualityController extends StateNotifier<AudioQuality> {
  DefaultQualityController() : super(AudioQuality.flac) {
    unawaited(_restore());
  }

  static const _key = 'player:default-quality';
  final _storage = const FlutterSecureStorage();
  var _hasUserSelection = false;

  Future<void> _restore() async {
    try {
      final value = await _storage.read(key: _key);
      if (!_hasUserSelection) {
        state = AudioQuality.values
                .where((quality) => quality.name == value)
                .firstOrNull ??
            AudioQuality.flac;
      }
    } on Object {
      // SQ remains the safe session fallback when system storage is unavailable.
    }
  }

  Future<void> setQuality(AudioQuality quality) async {
    _hasUserSelection = true;
    state = quality;
    try {
      await _storage.write(key: _key, value: quality.name);
    } on Object {
      // Keep the chosen quality for this session if persistence is unavailable.
    }
  }
}
