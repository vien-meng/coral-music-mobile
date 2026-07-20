import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../state/playback_queue_controller.dart';
import '../state/player_controller.dart';

class PlayerTransportControls extends ConsumerWidget {
  const PlayerTransportControls({
    required this.track,
    required this.player,
    this.toggleKey,
    super.key,
  });

  final Track track;
  final PlayerState player;
  final Key? toggleKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final queue = ref.watch(playbackQueueProvider);
    final duration = player.track?.id == track.id
        ? player.duration ?? track.duration
        : track.duration;
    final position =
        player.track?.id == track.id ? player.position : Duration.zero;
    final hasProgress = duration != null && duration > Duration.zero;
    final maxMilliseconds =
        hasProgress ? duration.inMilliseconds.toDouble() : 1.0;
    final progressMilliseconds = hasProgress
        ? math.min(position.inMilliseconds.toDouble(), maxMilliseconds)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 1.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: scheme.primary,
            inactiveTrackColor: scheme.primary.withValues(alpha: .18),
            thumbColor: scheme.surface,
          ),
          child: Slider(
            value: progressMilliseconds,
            max: maxMilliseconds,
            onChanged: hasProgress
                ? (value) => ref
                    .read(playerProvider.notifier)
                    .seek(Duration(milliseconds: value.round()))
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(_duration(position)), Text(_duration(duration))],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一首',
              onPressed: queue.tracks.length > 1
                  ? () => _playSibling(ref, previous: true)
                  : null,
              icon: const Icon(Icons.skip_previous, size: 29),
            ),
            const SizedBox(width: 18),
            SizedBox.square(
              dimension: 58,
              child: FilledButton(
                key: toggleKey,
                onPressed: () =>
                    ref.read(playerProvider.notifier).toggle(track),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                child: Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 31,
                ),
              ),
            ),
            const SizedBox(width: 18),
            IconButton(
              tooltip: '下一首',
              onPressed:
                  queue.tracks.length > 1 ? () => _playSibling(ref) : null,
              icon: const Icon(Icons.skip_next, size: 29),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _playSibling(WidgetRef ref, {bool previous = false}) async {
    final queue = ref.read(playbackQueueProvider.notifier);
    final sibling = previous ? queue.selectPrevious() : queue.selectNext();
    if (sibling != null) {
      await ref.read(playerProvider.notifier).playTrack(sibling);
    }
  }
}

String _duration(Duration? value) {
  if (value == null) return '--:--';
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
