import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/cover_image.dart';
import '../../../app/app_theme.dart';
import '../../../domain/music.dart';
import '../data/audio_engine.dart';
import '../state/playback_queue_controller.dart';
import '../state/player_controller.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueTrack = ref.watch(
      playbackQueueProvider.select((queue) => queue.currentTrack),
    );
    final canSkip = ref.watch(
      playbackQueueProvider.select(
        (queue) => queue.currentTrack != null && queue.tracks.length > 1,
      ),
    );
    final player = ref.watch(playerProvider);
    final track = player.track ?? queueTrack;
    final colors = Theme.of(context).colorScheme;
    final duration = player.duration;
    final progress = duration == null || duration <= Duration.zero
        ? 0.0
        : player.position.inMilliseconds / duration.inMilliseconds;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: CoralPalette.brand.withValues(alpha: .05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/player'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 5, 7, 4),
                child: Row(
                  children: [
                    _MiniArtwork(track: track),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track?.title ?? '未在播放',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            track == null
                                ? '从首页、发现或列表选择歌曲'
                                : player.error?.message ??
                                    '${track.artist.isEmpty ? '未知歌手' : track.artist} · ${_statusText(player.status)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: player.error == null
                                          ? colors.onSurfaceVariant
                                          : colors.error,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '上一曲',
                      onPressed: canSkip
                          ? () => _playSibling(ref, previous: true)
                          : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        maximumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.skip_previous, size: 22),
                    ),
                    IconButton.outlined(
                      tooltip: player.isPlaying ? '暂停' : '播放',
                      onPressed: track == null
                          ? null
                          : () =>
                              ref.read(playerProvider.notifier).toggle(track),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(38, 38),
                        backgroundColor: colors.primary.withValues(alpha: .1),
                        foregroundColor: colors.primary,
                        side: BorderSide(
                          color: colors.primary.withValues(alpha: .42),
                        ),
                      ),
                      icon: Icon(
                        player.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                    IconButton(
                      tooltip: '下一曲',
                      onPressed: canSkip ? () => _playSibling(ref) : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        maximumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.skip_next, size: 22),
                    ),
                  ],
                ),
              ),
              if (player.track?.id == track?.id && duration != null)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 1.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 3),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.primary.withValues(alpha: .14),
                    thumbColor: colors.surface,
                  ),
                  child: SizedBox(
                    height: 6,
                    child: Slider(
                      value: progress.clamp(0, 1),
                      onChanged: (value) =>
                          ref.read(playerProvider.notifier).seek(Duration(
                                milliseconds:
                                    (duration.inMilliseconds * value).round(),
                              )),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playSibling(WidgetRef ref, {bool previous = false}) async {
    final queue = ref.read(playbackQueueProvider.notifier);
    final sibling = previous ? queue.selectPrevious() : queue.selectNext();
    if (sibling != null) {
      await ref.read(playerProvider.notifier).playTrack(sibling);
    }
  }

  static String _statusText(AudioEngineStatus status) => switch (status) {
        AudioEngineStatus.loading => '正在加载',
        AudioEngineStatus.playing => '正在播放',
        AudioEngineStatus.paused => '已暂停',
        AudioEngineStatus.completed => '播放完成',
        _ => '准备播放',
      };
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(7)),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Icon(Icons.music_note_outlined,
          color: Theme.of(context).colorScheme.onPrimaryContainer),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: CoverImage(
        uri: track?.coverUri,
        fallback: placeholder,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
      ),
    );
  }
}
