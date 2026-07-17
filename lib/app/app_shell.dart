import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/player/view/mini_player.dart';
import 'app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static const _mobileDestinations = [
    _ShellDestination('/leaderboard', '首页', Icons.home_rounded),
    _ShellDestination('/search', '发现', Icons.explore_outlined),
    _ShellDestination('/player', '播放', Icons.graphic_eq_rounded),
    _ShellDestination('/more', '我的', Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final useNavigationRail = size.width >= 720 && size.height >= 720;
    final selectedIndex = _selectedIndex(location);
    final content = useNavigationRail
        ? Row(
            children: [
              _CoralRail(
                selectedIndex: selectedIndex,
                onSelected: (index) => _go(context, index),
              ),
              VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
              Expanded(child: child),
            ],
          )
        : child;

    return Scaffold(
      // Keep the live mini player above the bottom navigation on phones.
      extendBody: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: coralPageGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: content),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: MiniPlayer(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: useNavigationRail
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              destinations: [
                for (final item in _mobileDestinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
              onDestinationSelected: (index) => _go(context, index),
            ),
    );
  }

  int _selectedIndex(String path) {
    final index = _mobileDestinations.indexWhere((item) => item.path == path);
    return index < 0 ? 3 : index;
  }

  void _go(BuildContext context, int index) {
    final path = _mobileDestinations[index].path;
    if (path == '/player') {
      context.push(path);
      return;
    }
    context.go(path);
  }
}

class _CoralRail extends StatelessWidget {
  const _CoralRail({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationRail(
        backgroundColor: Colors.white.withValues(alpha: .56),
        selectedIndex: selectedIndex,
        labelType: NavigationRailLabelType.all,
        leading: const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 24),
          child: _BrandMark(),
        ),
        destinations: [
          for (final item in AppShell._mobileDestinations)
            NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon),
              label: Text(item.label),
            ),
        ],
        onDestinationSelected: onSelected,
      );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient:
              LinearGradient(colors: [CoralPalette.mint, CoralPalette.player]),
          boxShadow: [
            BoxShadow(
                color: Color(0x332ad4d7), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: const Icon(Icons.music_note_rounded, color: Colors.white),
      );
}

class _ShellDestination {
  const _ShellDestination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}
