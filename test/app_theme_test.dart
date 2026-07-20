import 'package:coral_music_mobile/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('module outline follows the active light or dark theme', () {
    final light = coralTheme(Brightness.light).colorScheme;
    final dark = coralTheme(Brightness.dark).colorScheme;

    expect(light.outlineVariant, isNot(CoralPalette.border));
    expect(dark.outlineVariant, isNot(light.outlineVariant));
    expect(light.outlineVariant.r, greaterThan(light.outlineVariant.b));
    expect(dark.outlineVariant.r, greaterThan(dark.outlineVariant.b));
  });
}
