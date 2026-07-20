import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/player/state/user_api_debug_controller.dart';
import 'package:coral_music_mobile/features/player/state/playback_queue_controller.dart';
import 'package:coral_music_mobile/features/player/view/mini_player.dart';
import 'package:coral_music_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_catalog_service.dart';

void main() {
  testWidgets('initializes the persisted User API source at app startup',
      (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(container.exists(userApiDebugProvider), isTrue);
  });

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

  testWidgets('loads daily recommendation and starts the music radio',
      (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('每日推荐'));
    await tester.pumpAndSettle();
    expect(find.text('今日推荐：测试榜单'), findsOneWidget);

    await tester.tap(find.text('音乐电台'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(container.read(playbackQueueProvider).mode, PlaybackMode.shuffle);
    expect(container.read(playbackQueueProvider).currentTrack?.title, '测试歌曲');
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
    await _openPlayer(tester);

    expect(find.text('正在播放'), findsOneWidget);
    expect(find.text('测试歌曲'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byTooltip('播放音质'),
      250,
      scrollable: find.byType(SingleChildScrollView),
    );
    expect(find.text('音量'), findsNothing);
    expect(find.text('定时停止'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('收藏')).dy,
      tester.getTopLeft(find.text('下载')).dy,
    );

    await tester.tap(find.byTooltip('播放音质'));
    await tester.pumpAndSettle();

    expect(find.text('播放音质'), findsOneWidget);
    expect(find.text('FLAC 无损音频'), findsOneWidget);
    expect(find.text('320 kbps 高品质'), findsOneWidget);
    await tester.tap(find.text('HQ'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('查看歌词'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lyrics-track-header')), findsOneWidget);
    expect(find.byKey(const Key('lyrics-player-controls')), findsOneWidget);
    expect(find.byKey(const Key('lyrics-player-toggle')), findsOneWidget);
    expect(find.text('暂无可用歌词'), findsOneWidget);
  });

  testWidgets('swipes between player and lyrics and pulls down to close',
      (tester) async {
    await _openPlayer(tester);

    await tester.fling(
      find.byKey(const Key('player-detail-pages')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('查看播放'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('player-detail-pages')),
      const Offset(400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('查看歌词'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('player-panel')),
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('player-detail-pages')), findsNothing);
    expect(find.byType(MiniPlayer), findsOneWidget);
  });

  testWidgets('opens download manager from player download feedback',
      (tester) async {
    await _openPlayer(tester);
    await tester.scrollUntilVisible(
      find.text('下载'),
      250,
      scrollable: find.byType(SingleChildScrollView),
    );

    await tester.tap(find.text('下载'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();

    expect(find.text('下载管理'), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(find.byTooltip('返回'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('我的'), findsOneWidget);
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
    expect(find.text('音乐平台'), findsOneWidget);
    await tester.tap(find.text('QQ音乐'));
    await tester.pumpAndSettle();

    expect(find.text('QQ 测试榜单'), findsWidgets);
    expect(find.text('QQ 测试歌曲'), findsOneWidget);
  });

  testWidgets('opens the empty notification menu', (tester) async {
    await tester
        .pumpWidget(CoralMusicApp(catalogService: FakeCatalogService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();

    expect(find.text('消息通知'), findsOneWidget);
    expect(find.text('暂无新消息'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

Future<void> _openPlayer(WidgetTester tester) async {
  await tester.pumpWidget(
    CoralMusicApp(catalogService: FakeCatalogService()),
  );
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
}
