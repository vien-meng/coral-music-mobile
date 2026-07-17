import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'app_theme.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.destination, super.key});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              destination.icon,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              destination.label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('功能按开发计划逐项接入。'),
          ],
        ),
      );
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static const _quickPaths = {'/list', '/favorites', '/download', '/setting'};

  @override
  Widget build(BuildContext context) {
    final quick = appDestinations
        .where((item) => _quickPaths.contains(item.path))
        .toList();
    final entries = appDestinations
        .where((item) =>
            !_quickPaths.contains(item.path) &&
            item.path != '/search' &&
            item.path != '/leaderboard')
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Text(
              '我的',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              tooltip: '设置',
              onPressed: () => context.push('/setting'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _ProfileCard(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
            child: Row(
              children: [
                for (final item in quick)
                  Expanded(
                    child: _QuickEntry(
                      destination: item,
                      onTap: () => item.path == '/setting'
                          ? context.push(item.path)
                          : context.go(item.path),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('功能与设置',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                _ProfileEntry(
                  destination: entries[index],
                  onTap: () => context.go(entries[index].path),
                ),
                if (index != entries.length - 1)
                  const Divider(height: 1, indent: 56),
              ],
              const Divider(height: 1, indent: 56),
              _ProfileEntry(
                destination: const AppDestination(
                  name: 'setting',
                  path: '/setting',
                  label: '主题与设置',
                  icon: Icons.tune_rounded,
                ),
                onTap: () => context.push('/setting'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CoralPalette.sky,
              CoralPalette.periwinkle,
              CoralPalette.pink
            ],
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1c6b5cbe), blurRadius: 20, offset: Offset(0, 9)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .65),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: CoralPalette.player, size: 30),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coral Music · Free',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('本地收藏与播放队列，始终留在你的设备中'),
                ],
              ),
            ),
          ],
        ),
      );
}

class _QuickEntry extends StatelessWidget {
  const _QuickEntry({required this.destination, required this.onTap});

  final AppDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              Icon(destination.icon, color: CoralPalette.mint),
              const SizedBox(height: 7),
              Text(destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
}

class _ProfileEntry extends StatelessWidget {
  const _ProfileEntry({required this.destination, required this.onTap});

  final AppDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: CoralPalette.sky.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(destination.icon, size: 19, color: CoralPalette.player),
        ),
        title: Text(destination.label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
