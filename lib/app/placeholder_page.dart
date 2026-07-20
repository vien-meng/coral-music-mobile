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
    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
          const SizedBox(height: 18),
          const _ProfileCard(),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
          const SizedBox(height: 28),
          Text('功能与设置',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
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
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: CoralPalette.sky,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.music_note_outlined,
                  color: CoralPalette.player, size: 26),
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
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              Icon(destination.icon, color: CoralPalette.brand, size: 21),
              const SizedBox(height: 6),
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
            color: CoralPalette.sky,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(destination.icon, size: 19, color: CoralPalette.brand),
        ),
        title: Text(destination.label),
        trailing: const Icon(Icons.chevron_right_outlined),
        onTap: onTap,
      );
}
