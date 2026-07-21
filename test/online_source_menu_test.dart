import 'package:coral_music_mobile/app/online_source_menu.dart';
import 'package:coral_music_mobile/domain/music.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only exposes platforms declared by the active User API', () {
    expect(
      supportedOnlineSources(
        const [OnlineSource.kuwo, OnlineSource.kugou, OnlineSource.qq],
        {'kg', 'tx'},
      ),
      [OnlineSource.kugou, OnlineSource.qq],
    );
  });

  testWidgets('uses a shared source menu and forwards the selected source',
      (tester) async {
    OnlineSource? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineSourceMenu(
            activeSource: OnlineSource.kuwo,
            sources: const [OnlineSource.kuwo, OnlineSource.qq],
            onSelected: (source) => selected = source,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('切换音乐来源'));
    await tester.pumpAndSettle();
    expect(find.text('音乐平台'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.widgetWithText(MenuItemButton, 'QQ音乐'));
    await tester.pumpAndSettle();
    expect(selected, OnlineSource.qq);
  });
}
