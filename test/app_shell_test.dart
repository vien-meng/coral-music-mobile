import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/view/mini_player.dart';
import 'package:coral_music_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_catalog_service.dart';

void main() {
  testWidgets('opens leaderboard and exposes every mobile route',
      (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    expect(find.text('珊瑚音乐 · 排行榜'), findsOneWidget);
    expect(find.text('测试榜单'), findsOneWidget);
    expect(find.text('未在播放'), findsOneWidget);

    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();

    expect(find.text('珊瑚音乐 · 下载'), findsOneWidget);
  });

  testWidgets('play all replaces queue and updates mini player',
      (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放全部'));
    await tester.pump();

    expect(find.text('测试歌曲'), findsNWidgets(2));
    expect(find.text('测试歌手 · 准备播放'), findsOneWidget);
  });

  testWidgets('opens the player detail and its lyrics empty state',
      (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放全部'));
    await tester.pump();
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();

    expect(find.text('播放详情'), findsOneWidget);
    expect(find.text('测试歌曲'), findsOneWidget);

    await tester.tap(find.byTooltip('查看歌词'));
    await tester.pumpAndSettle();

    expect(find.text('暂无可用歌词'), findsOneWidget);
  });

  testWidgets('search result replaces queue and updates mini player',
      (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '测试');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试歌曲'));
    await tester.pump();

    expect(find.text('测试歌手 · 准备播放'), findsOneWidget);
  });

  testWidgets('switches the leaderboard source', (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<OnlineSource>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QQ音乐').last);
    await tester.pumpAndSettle();

    expect(find.text('QQ 测试榜单'), findsOneWidget);
    expect(find.text('QQ 测试歌曲'), findsOneWidget);
  });

  testWidgets('uses a navigation rail on a wide screen without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
