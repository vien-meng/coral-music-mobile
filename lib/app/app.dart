import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/leaderboard/data/online_catalog_service.dart';
import '../features/leaderboard/state/leaderboard_controller.dart';
import '../features/player/state/player_controller.dart';
import 'app_router.dart';
import 'app_theme.dart';

class CoralMusicApp extends StatelessWidget {
  const CoralMusicApp({super.key, this.catalogService});

  final OnlineCatalogService? catalogService;

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: [
          if (catalogService != null)
            onlineCatalogServiceProvider.overrideWithValue(catalogService!),
        ],
        child: const _PlaybackRestore(
          child: _CoralMaterialApp(),
        ),
      );
}

class _PlaybackRestore extends ConsumerStatefulWidget {
  const _PlaybackRestore({required this.child});

  final Widget child;

  @override
  ConsumerState<_PlaybackRestore> createState() => _PlaybackRestoreState();
}

class _PlaybackRestoreState extends ConsumerState<_PlaybackRestore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(playerProvider.notifier).restoreLastPlayback());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CoralMaterialApp extends StatelessWidget {
  const _CoralMaterialApp();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: '珊瑚音乐',
        debugShowCheckedModeBanner: false,
        theme: coralTheme(Brightness.light),
        darkTheme: coralTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        routerConfig: createAppRouter(),
      );
}
