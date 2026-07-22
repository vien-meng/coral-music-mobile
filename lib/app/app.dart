import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/music.dart';
import '../features/leaderboard/data/online_catalog_service.dart';
import '../features/library/state/library_controller.dart';
import '../features/leaderboard/state/leaderboard_controller.dart';
import '../features/player/state/player_controller.dart';
import '../features/player/state/default_quality_controller.dart';
import '../features/player/state/user_api_debug_controller.dart';
import 'app_router.dart';
import 'app_theme.dart';
import 'shared_audio_receiver.dart';
import 'theme_mode_controller.dart';

double coralTextScaleForWidth(double width) =>
    (width / 390).clamp(.88, 1).toDouble();

TextScaler coralTextScalerForWidth(TextScaler textScaler, double width) =>
    TextScaler.linear(textScaler.scale(1) * coralTextScaleForWidth(width));

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

class _PlaybackRestoreState extends ConsumerState<_PlaybackRestore>
    with WidgetsBindingObserver {
  late final ProviderSubscription<List<String>> _sharedAudioSubscription;
  late final ProviderSubscription<AudioQuality> _qualitySubscription;
  var _isImportingSharedAudio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(userApiDebugProvider.notifier);
    _sharedAudioSubscription = ref.listenManual<List<String>>(
      sharedAudioPathsProvider,
      (_, paths) => unawaited(_importSharedAudio(paths)),
      fireImmediately: true,
    );
    _qualitySubscription = ref.listenManual<AudioQuality>(
      defaultPlaybackQualityProvider,
      (_, quality) =>
          ref.read(playerProvider.notifier).setDefaultQuality(quality),
      fireImmediately: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restorePlayback());
      unawaited(SharedAudioReceiver.install(ref));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(userApiDebugProvider.notifier).restoreRuntime());
    }
  }

  Future<void> _restorePlayback() async {
    await ref.read(userApiDebugProvider.notifier).restorePersisted();
    if (!mounted) return;
    await ref.read(playerProvider.notifier).restoreLastPlayback();
  }

  Future<void> _importSharedAudio(List<String> paths) async {
    if (paths.isEmpty || _isImportingSharedAudio) return;
    _isImportingSharedAudio = true;
    try {
      await ref.read(libraryProvider.notifier).importSharedAudio(paths);
    } finally {
      if (identical(ref.read(sharedAudioPathsProvider), paths)) {
        ref.read(sharedAudioPathsProvider.notifier).state = const [];
      }
      _isImportingSharedAudio = false;
      final pending = ref.read(sharedAudioPathsProvider);
      if (pending.isNotEmpty) unawaited(_importSharedAudio(pending));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sharedAudioSubscription.close();
    _qualitySubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CoralMaterialApp extends ConsumerStatefulWidget {
  const _CoralMaterialApp();

  @override
  ConsumerState<_CoralMaterialApp> createState() => _CoralMaterialAppState();
}

class _CoralMaterialAppState extends ConsumerState<_CoralMaterialApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: '珊瑚音乐',
        debugShowCheckedModeBanner: false,
        theme: coralTheme(Brightness.light),
        darkTheme: coralTheme(Brightness.dark),
        themeMode: ref.watch(appThemeModeProvider),
        routerConfig: _router,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: coralTextScalerForWidth(
                mediaQuery.textScaler,
                mediaQuery.size.width,
              ),
            ),
            child: child!,
          );
        },
      );
}
