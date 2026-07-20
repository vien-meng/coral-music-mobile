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

    expect(find.text('发现'), findsWidgets);
    expect(find.text('测试榜单'), findsWidgets);
    expect(find.text('未在播放'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();

    expect(find.text('下载'), findsOneWidget);
  });

  testWidgets('play all replaces queue and updates mini player',
      (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('播放全部'),
      300,
      scrollable: find.byKey(const Key('leaderboard-tracks')),
    );
    await tester.tap(find.text('播放全部'));
    await tester.pump();

    expect(find.text('测试歌曲'), findsNWidgets(2));
  });

  testWidgets('keeps the mini player above the bottom navigation',
      (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    final miniPlayer = tester.getRect(find.byType(MiniPlayer));
    final navigationItem = tester.getRect(find.text('我的').last);

    expect(miniPlayer.bottom, lessThanOrEqualTo(navigationItem.top));
  });

  testWidgets('opens the player detail and its lyrics empty state',
      (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('播放全部'),
      300,
      scrollable: find.byKey(const Key('leaderboard-tracks')),
    );
    await tester.tap(find.text('播放全部'));
    await tester.pump();
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();

    expect(find.text('正在播放'), findsOneWidget);
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

    await tester.tap(find.text('搜索').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '测试');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试歌曲'));
    await tester.pump();

    expect(find.text('测试歌曲'), findsNWidgets(2));
  });

  testWidgets('switches the leaderboard source', (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('切换音乐来源'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('QQ音乐'),
        matching: find.byType(CheckedPopupMenuItem<OnlineSource>),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QQ 测试榜单'), findsWidgets);
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
