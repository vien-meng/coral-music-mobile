import 'package:coral_music_mobile/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reduces themed text on narrow screens without shrinking below 88%', () {
    final narrow = coralTextScalerForWidth(TextScaler.noScaling, 320);

    expect(coralTextScaleForWidth(320), closeTo(.88, .001));
    expect(coralTextScaleForWidth(390), 1);
    expect(narrow.scale(20), closeTo(17.6, .001));
  });
}
