import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/library/view/library_page.dart';
import '../features/library/view/history_page.dart';
import '../features/webdav/view/webdav_page.dart';
import '../features/download/view/download_page.dart';
import '../features/leaderboard/view/leaderboard_page.dart';
import '../features/search/view/search_page.dart';
import '../features/song_list/view/song_list_page.dart';
import '../features/player/view/player_detail_page.dart';
import '../features/player/view/user_api_debug_page.dart';
import '../features/settings/view/settings_page.dart';
import '../features/settings/view/ignored_tracks_page.dart';
import '../features/settings/view/library_backup_page.dart';
import 'app_shell.dart';
import 'app_back_navigation.dart';
import 'placeholder_page.dart';

GoRouter createAppRouter() => GoRouter(
      initialLocation: '/leaderboard',
      redirect: (_, state) => normalizeCoralMusicDeepLink(state.uri),
      routes: [
        GoRoute(
          name: 'player',
          path: '/player',
          pageBuilder: (context, state) => _page(
            state,
            const PlayerDetailPage(),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  name: 'leaderboard',
                  path: '/leaderboard',
                  pageBuilder: (context, state) =>
                      _page(state, const LeaderboardPage()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  name: 'search',
                  path: '/search',
                  pageBuilder: (context, state) =>
                      _page(state, const SearchPage()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  name: 'more',
                  path: '/more',
                  pageBuilder: (context, state) =>
                      _page(state, const MorePage()),
                ),
                GoRoute(
                  name: 'song-list',
                  path: '/song-list',
                  pageBuilder: (context, state) =>
                      _page(state, const SongListPage()),
                ),
                GoRoute(
                  name: 'list',
                  path: '/list',
                  pageBuilder: (context, state) =>
                      _page(state, const AppBackScope(child: LibraryPage())),
                ),
                GoRoute(
                  name: 'favorites',
                  path: '/favorites',
                  pageBuilder: (context, state) => _page(
                    state,
                    const AppBackScope(
                      child: LibraryPage(favoritesOnly: true),
                    ),
                  ),
                ),
                GoRoute(
                  name: 'library',
                  path: '/library',
                  pageBuilder: (context, state) =>
                      _page(state, const HistoryPage()),
                ),
                GoRoute(
                  name: 'download',
                  path: '/download',
                  pageBuilder: (context, state) =>
                      _page(state, const AppBackScope(child: DownloadPage())),
                ),
                GoRoute(
                  name: 'webdav',
                  path: '/webdav',
                  pageBuilder: (context, state) =>
                      _page(state, const WebDavPage()),
                ),
                GoRoute(
                  name: 'setting',
                  path: '/setting',
                  pageBuilder: (context, state) =>
                      _page(state, const AppBackScope(child: SettingsPage())),
                ),
                GoRoute(
                  name: 'source-management',
                  path: '/setting/source',
                  pageBuilder: (context, state) =>
                      _page(state, const UserApiDebugPage()),
                ),
                GoRoute(
                  name: 'ignored-tracks',
                  path: '/setting/ignored',
                  pageBuilder: (context, state) =>
                      _page(state, const IgnoredTracksPage()),
                ),
                GoRoute(
                  name: 'library-backup',
                  path: '/setting/backup',
                  pageBuilder: (context, state) =>
                      _page(state, const LibraryBackupPage()),
                ),
              ],
            ),
          ],
        ),
      ],
    );

String? normalizeCoralMusicDeepLink(Uri uri) {
  if (uri.scheme != 'coralmusic') return null;
  final path = uri.path.isEmpty || uri.path == '/' ? uri.host : uri.path;
  return switch (path.startsWith('/') ? path : '/$path') {
    '/player' => '/player',
    '/leaderboard' => '/leaderboard',
    '/search' => '/search',
    '/song-list' => '/song-list',
    '/list' => '/list',
    '/favorites' => '/favorites',
    '/library' => '/library',
    '/download' => '/download',
    '/webdav' => '/webdav',
    '/setting' => '/setting',
    _ => '/leaderboard',
  };
}

NoTransitionPage<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage(key: state.pageKey, child: child);

final class AppDestination {
  const AppDestination({
    required this.name,
    required this.path,
    required this.label,
    required this.icon,
  });

  final String name;
  final String path;
  final String label;
  final IconData icon;
}

const appDestinations = <AppDestination>[
  AppDestination(
    name: 'search',
    path: '/search',
    label: '搜索',
    icon: Icons.search,
  ),
  AppDestination(
    name: 'song-list',
    path: '/song-list',
    label: '歌单广场',
    icon: Icons.queue_music_outlined,
  ),
  AppDestination(
    name: 'leaderboard',
    path: '/leaderboard',
    label: '排行榜',
    icon: Icons.leaderboard_outlined,
  ),
  AppDestination(
    name: 'list',
    path: '/list',
    label: '我的列表',
    icon: Icons.library_music_outlined,
  ),
  AppDestination(
    name: 'favorites',
    path: '/favorites',
    label: '我的收藏',
    icon: Icons.favorite_border,
  ),
  AppDestination(
    name: 'library',
    path: '/library',
    label: '音乐分类',
    icon: Icons.category_outlined,
  ),
  AppDestination(
    name: 'download',
    path: '/download',
    label: '下载',
    icon: Icons.download_outlined,
  ),
  AppDestination(
    name: 'webdav',
    path: '/webdav',
    label: '网盘资源',
    icon: Icons.cloud_outlined,
  ),
  AppDestination(
    name: 'setting',
    path: '/setting',
    label: '设置',
    icon: Icons.settings_outlined,
  ),
];
