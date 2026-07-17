import 'package:coral_music_mobile/app/placeholder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('returns to More after opening settings', (tester) async {
    final router = GoRouter(
      initialLocation: '/more',
      routes: [
        GoRoute(path: '/more', builder: (_, __) => const MorePage()),
        GoRoute(
          path: '/setting',
          builder: (_, __) => const Scaffold(body: Text('音源管理')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('音源管理'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('我的'), findsOneWidget);
  });
}
