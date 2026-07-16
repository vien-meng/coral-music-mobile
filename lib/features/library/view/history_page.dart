import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
import '../data/library_store.dart';

final playbackHistoryProvider = FutureProvider<List<PlayHistoryEntry>>(
  (ref) => ref.watch(libraryStoreProvider).listHistory(),
);

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(playbackHistoryProvider);
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(playbackHistoryProvider),
          child: const Text('历史加载失败，点击重试'),
        ),
      ),
      data: (entries) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text('播放历史', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: entries.isEmpty
                      ? null
                      : () async {
                          await ref.read(libraryStoreProvider).clearHistory();
                          ref.invalidate(playbackHistoryProvider);
                        },
                  child: const Text('清空'),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('还没有播放历史。'))
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                          entry.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${entry.track.artist.isEmpty ? '未知歌手' : entry.track.artist} · 播放 ${entry.playCount} 次 · 上次 ${_duration(entry.lastPosition)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          final tracks =
                              entries.map((item) => item.track).toList();
                          ref.read(playbackQueueProvider.notifier).replaceQueue(
                                tracks,
                                startIndex: index,
                                contextId: 'history',
                              );
                          await ref.read(playerProvider.notifier).playTrack(
                                entry.track,
                                initialPosition: entry.lastPosition,
                              );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String _duration(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
