import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/leaderboard/view/leaderboard_page.dart';
import '../features/search/view/search_page.dart';
import 'app_shell.dart';
import 'placeholder_page.dart';

GoRouter createAppRouter() => GoRouter(
      initialLocation: '/leaderboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(
            location: state.uri.path,
            child: child,
          ),
          routes: [
            for (final destination in appDestinations)
              GoRoute(
                name: destination.name,
                path: destination.path,
                builder: (context, state) {
                  if (destination.name == 'leaderboard') {
                    return const LeaderboardPage();
                  }
                  if (destination.name == 'search') return const SearchPage();
                  return PlaceholderPage(destination: destination);
                },
              ),
            GoRoute(
              name: 'more',
              path: '/more',
              builder: (context, state) => const MorePage(),
            ),
          ],
        ),
      ],
    );

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
    icon: Icons.queue_music,
  ),
  AppDestination(
    name: 'leaderboard',
    path: '/leaderboard',
    label: '排行榜',
    icon: Icons.leaderboard,
  ),
  AppDestination(
    name: 'list',
    path: '/list',
    label: '我的列表',
    icon: Icons.library_music,
  ),
  AppDestination(
    name: 'favorites',
    path: '/favorites',
    label: '我的收藏',
    icon: Icons.favorite,
  ),
  AppDestination(
    name: 'library',
    path: '/library',
    label: '音乐分类',
    icon: Icons.category,
  ),
  AppDestination(
    name: 'download',
    path: '/download',
    label: '下载',
    icon: Icons.download,
  ),
  AppDestination(
    name: 'webdav',
    path: '/webdav',
    label: '网盘资源',
    icon: Icons.cloud,
  ),
  AppDestination(
    name: 'setting',
    path: '/setting',
    label: '设置',
    icon: Icons.settings,
  ),
];
