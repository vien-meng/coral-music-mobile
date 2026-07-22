import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/cover_image.dart';
import '../../../domain/music.dart';
import '../../download/view/download_track_button.dart';
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('播放队列',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${queue.tracks.length} 首 · ${_modeLabel(queue.mode)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭队列',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: queue.tracks.isEmpty
                  ? const Center(child: Text('播放队列为空'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
                      buildDefaultDragHandles: false,
                      itemCount: queue.tracks.length,
                      onReorder: ref.read(playbackQueueProvider.notifier).move,
                      itemBuilder: (context, index) {
                        final track = queue.tracks[index];
                        final isCurrent = index == queue.currentIndex;
                        return Material(
                          key: ValueKey(track.id),
                          color: isCurrent
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: .72)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              ref
                                  .read(playbackQueueProvider.notifier)
                                  .select(index);
                              await ref
                                  .read(playerProvider.notifier)
                                  .playTrack(track);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
                              child: Row(
                                children: [
                                  _QueueArtwork(
                                    track: track,
                                    isCurrent: isCurrent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (isCurrent) ...[
                                              Icon(
                                                Icons.graphic_eq_rounded,
                                                size: 15,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              child: Text(
                                                track.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: isCurrent
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${track.artist.isEmpty ? '未知歌手' : track.artist} · ${_sourceLabel(track)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (track.sourceKind ==
                                          TrackSourceKind.online ||
                                      track.sourceKind ==
                                          TrackSourceKind.webdav)
                                    DownloadTrackButton(
                                      track: track,
                                      compact: true,
                                    ),
                                  if (!isCurrent)
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        minimumSize: const Size.square(40),
                                        padding: EdgeInsets.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      tooltip: '移出队列',
                                      onPressed: () => ref
                                          .read(playbackQueueProvider.notifier)
                                          .removeAt(index),
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                    ),
                                  if (!isCurrent)
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(Icons.drag_handle_rounded),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
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
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Icon(
        isCurrent ? Icons.graphic_eq : Icons.music_note_rounded,
        size: 22,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
    return SizedBox.square(
      dimension: 52,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CoverImage(uri: track.coverUri, fallback: fallback),
          ),
          if (isCurrent)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(3),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.graphic_eq_rounded,
                    size: 13, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

String _modeLabel(PlaybackMode mode) => switch (mode) {
      PlaybackMode.listLoop => '列表循环',
      PlaybackMode.singleLoop => '单曲循环',
      PlaybackMode.shuffle => '随机播放',
    };

String _sourceLabel(Track track) => switch (track.sourceKind) {
      TrackSourceKind.online => OnlineSource.values
              .where((source) => source.id == track.sourceId)
              .firstOrNull
              ?.label ??
          track.sourceId,
      TrackSourceKind.local => '本地音乐',
      TrackSourceKind.download => '已下载',
      TrackSourceKind.webdav => 'WebDAV',
    };
