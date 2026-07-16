import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

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

  static const _primaryPaths = {'/leaderboard', '/search', '/list'};

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          for (final destination in appDestinations)
            if (!_primaryPaths.contains(destination.path))
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(destination.path),
              ),
        ],
      );
}
