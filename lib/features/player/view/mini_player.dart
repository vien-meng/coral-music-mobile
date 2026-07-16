import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .72)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x160e1450), blurRadius: 20, offset: Offset(0, 7)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/player'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 7),
                child: Row(
                  children: [
                    _MiniArtwork(track: track),
                    const SizedBox(width: 10),
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
                          const SizedBox(height: 2),
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
                    IconButton.filled(
                      tooltip: player.isPlaying ? '暂停' : '播放',
                      onPressed: track == null
                          ? null
                          : () =>
                              ref.read(playerProvider.notifier).toggle(track),
                      style: IconButton.styleFrom(
                        backgroundColor: CoralPalette.player,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: colors.surfaceContainerHighest,
                      ),
                      icon: Icon(
                        player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              if (player.track?.id == track?.id && duration != null)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 3),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: SizedBox(
                    height: 10,
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
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(13)),
        gradient:
            LinearGradient(colors: [CoralPalette.sky, CoralPalette.lilac]),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    );
    if (track?.coverUri == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Image.network(
        track!.coverUri.toString(),
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
