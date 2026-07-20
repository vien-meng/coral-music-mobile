import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/cover_image.dart';
import '../../../domain/music.dart';
import '../../download/state/download_controller.dart';
import '../state/playback_queue_controller.dart';
import '../state/player_controller.dart';

class PlaybackQueueDrawer extends ConsumerWidget {
  const PlaybackQueueDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(playbackQueueProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text('播放队列'),
              subtitle: Text('${queue.tracks.length} 首歌曲'),
              trailing: IconButton(
                tooltip: '关闭队列',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: queue.tracks.isEmpty
                  ? const Center(child: Text('队列为空'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: queue.tracks.length,
                      onReorder: ref.read(playbackQueueProvider.notifier).move,
                      itemBuilder: (context, index) {
                        final track = queue.tracks[index];
                        final isCurrent = index == queue.currentIndex;
                        return ListTile(
                          key: ValueKey(track.id),
                          selected: isCurrent,
                          leading: _QueueArtwork(
                            track: track,
                            isCurrent: isCurrent,
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artist.isEmpty ? '未知歌手' : track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (track.sourceKind == TrackSourceKind.online ||
                                  track.sourceKind == TrackSourceKind.webdav)
                                IconButton(
                                  tooltip: '下载歌曲',
                                  onPressed: () => ref
                                      .read(downloadProvider.notifier)
                                      .enqueue(track),
                                  icon: const Icon(Icons.download_outlined),
                                ),
                              IconButton(
                                tooltip: isCurrent ? '当前播放歌曲不可删除' : '移出队列',
                                onPressed: isCurrent
                                    ? null
                                    : () => ref
                                        .read(playbackQueueProvider.notifier)
                                        .removeAt(index),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              if (!isCurrent)
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle),
                                ),
                            ],
                          ),
                          onTap: () async {
                            ref
                                .read(playbackQueueProvider.notifier)
                                .select(index);
                            await ref
                                .read(playerProvider.notifier)
                                .playTrack(track);
                            if (context.mounted) Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueArtwork extends StatelessWidget {
  const _QueueArtwork({required this.track, required this.isCurrent});

  final Track track;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [CoralPalette.sky, CoralPalette.lilac],
        ),
      ),
      child: Icon(
        isCurrent ? Icons.graphic_eq : Icons.music_note_rounded,
        size: 22,
        color: Colors.white,
      ),
    );
    return SizedBox.square(
      dimension: 44,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CoverImage(uri: track.coverUri, fallback: fallback),
      ),
    );
  }
}
