import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/leaderboard/data/online_catalog_service.dart';
import '../features/leaderboard/state/leaderboard_controller.dart';
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
        child: MaterialApp.router(
          title: '珊瑚音乐',
          debugShowCheckedModeBanner: false,
          theme: coralTheme(Brightness.light),
          darkTheme: coralTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          routerConfig: createAppRouter(),
        ),
      );
}
