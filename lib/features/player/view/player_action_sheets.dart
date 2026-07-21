import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/audio_quality_labels.dart';
import '../../../domain/music.dart';
import '../state/player_controller.dart';

Future<void> showPlayerQualitySheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
  AudioQuality selected, {
  Iterable<AudioQuality>? qualities,
}) {
  final controller = ref.read(playerProvider.notifier);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '播放音质',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '切换后会重新加载当前歌曲',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final quality in qualities ?? track.availableQualities)
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      selected: quality == selected,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .1),
                      leading: Icon(
                        quality == selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: quality == selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(audioQualityLabel(quality)),
                      subtitle: Text(audioQualityDescription(quality)),
                      onTap: quality == selected
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              controller.setQuality(quality);
                            },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showPlayerSleepTimerSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final player = ref.watch(playerProvider);
        final controller = ref.read(playerProvider.notifier);
        final endsAt = player.sleepTimerEndsAt;
        final minutes = endsAt == null
            ? null
            : endsAt.difference(DateTime.now()).inMinutes.clamp(0, 999) + 1;
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: const Text('定时停止'),
              subtitle: Text(player.stopAfterCurrent
                  ? '当前歌曲播放完成后停止'
                  : minutes == null
                      ? '未设置'
                      : '约 $minutes 分钟后停止'),
            ),
            for (final duration in const [15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$duration 分钟后停止'),
                onTap: () {
                  controller.setSleepTimer(Duration(minutes: duration));
                  Navigator.pop(context);
                },
              ),
            SwitchListTile(
              secondary: const Icon(Icons.stop_circle_outlined),
              title: const Text('当前歌曲结束后停止'),
              value: player.stopAfterCurrent,
              onChanged: controller.setStopAfterCurrent,
            ),
            if (endsAt != null || player.stopAfterCurrent)
              ListTile(
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('关闭定时停止'),
                onTap: () {
                  controller.setSleepTimer(null);
                  controller.setStopAfterCurrent(false);
                  Navigator.pop(context);
                },
              ),
          ]),
        );
      },
    ),
  );
}
