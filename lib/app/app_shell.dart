import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/player/view/mini_player.dart';
import 'app_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static const _primaryPaths = ['/leaderboard', '/search', '/list'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = appDestinations.indexWhere(
      (destination) => destination.path == location,
    );
    final destination = currentIndex < 0 ? null : appDestinations[currentIndex];
    final size = MediaQuery.sizeOf(context);
    final useNavigationRail = size.width >= 720 && size.height >= 720;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '珊瑚音乐 · ${destination?.label ?? '更多'}',
          key: const Key('route-title'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: useNavigationRail
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: currentIndex < 0 ? null : currentIndex,
                        labelType: NavigationRailLabelType.selected,
                        destinations: [
                          for (final item in appDestinations)
                            NavigationRailDestination(
                              icon: Icon(item.icon),
                              label: Text(item.label),
                            ),
                        ],
                        onDestinationSelected: (index) =>
                            context.go(appDestinations[index].path),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: child),
                    ],
                  )
                : child,
          ),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: useNavigationRail
          ? null
          : NavigationBar(
              selectedIndex: _primaryPaths.contains(location)
                  ? _primaryPaths.indexOf(location)
                  : 3,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.leaderboard),
                  label: '排行榜',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: '搜索',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music),
                  label: '我的列表',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: '更多',
                ),
              ],
              onDestinationSelected: (index) => context.go(
                index == 3 ? '/more' : _primaryPaths[index],
              ),
            ),
    );
  }
}
