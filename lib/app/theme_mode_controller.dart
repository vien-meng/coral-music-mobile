import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final appThemeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (_) => ThemeModeController(),
);

final class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    unawaited(_restore());
  }

  static const _key = 'app:theme-mode';
  final _storage = const FlutterSecureStorage();
  var _hasUserSelection = false;

  Future<void> _restore() async {
    try {
      final value = await _storage.read(key: _key);
      if (!_hasUserSelection) {
        state =
            ThemeMode.values.where((mode) => mode.name == value).firstOrNull ??
                ThemeMode.system;
      }
    } on Object {
      // The system mode remains a safe fallback when storage is unavailable.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _hasUserSelection = true;
    state = mode;
    try {
      await _storage.write(key: _key, value: mode.name);
    } on Object {
      // Keep the in-session preference when persistent storage is unavailable.
    }
  }
}
