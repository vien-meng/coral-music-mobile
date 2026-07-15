import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../data/audio_engine.dart';
import '../state/playback_queue_controller.dart';
import '../state/player_controller.dart';

enum _DetailPanel { player, lyrics }

class PlayerDetailPage extends ConsumerStatefulWidget {
  const PlayerDetailPage({super.key});

  @override
  ConsumerState<PlayerDetailPage> createState() => _PlayerDetailPageState();
}

class _PlayerDetailPageState extends ConsumerState<PlayerDetailPage> {
  var _panel = _DetailPanel.player;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final queueTrack = ref.watch(
      playbackQueueProvider.select((queue) => queue.currentTrack),
    );
    final track = player.track ?? queueTrack;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('播放详情'),
        actions: [
          IconButton(
            tooltip: _panel == _DetailPanel.player ? '查看歌词' : '查看播放',
            onPressed: () => setState(
              () => _panel = _panel == _DetailPanel.player
                  ? _DetailPanel.lyrics
                  : _DetailPanel.player,
            ),
            icon: Icon(
              _panel == _DetailPanel.player
                  ? Icons.lyrics_outlined
                  : Icons.album_outlined,
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primaryContainer, colors.surface],
          ),
        ),
        child: SafeArea(
          top: false,
          child: track == null
              ? const _NothingPlaying()
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _panel == _DetailPanel.player
                      ? _PlayerPanel(track: track, player: player)
                      : _LyricsPanel(track: track),
                ),
        ),
      ),
    );
  }
}

class _PlayerPanel extends ConsumerWidget {
  const _PlayerPanel({required this.track, required this.player});

  final Track track;
  final PlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return SingleChildScrollView(
      key: const ValueKey('player-panel'),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        children: [
          _AlbumArtwork(track: track),
          const SizedBox(height: 32),
          Text(
            track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            track.artist.isEmpty ? '未知歌手' : track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 28),
          Slider(
            value: progressMilliseconds,
            max: maxMilliseconds,
            onChanged: hasProgress
                ? (value) => ref
                    .read(playerProvider.notifier)
                    .seek(Duration(milliseconds: value.round()))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_duration(position)),
                Text(_duration(duration)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: '上一首',
                onPressed: ref.watch(playbackQueueProvider).tracks.length > 1
                    ? () => _playSibling(ref, previous: true)
                    : null,
                icon: const Icon(Icons.skip_previous),
              ),
              const SizedBox(width: 20),
              FilledButton.icon(
                key: const Key('player-detail-toggle'),
                onPressed: () =>
                    ref.read(playerProvider.notifier).toggle(track),
                icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(player.isPlaying ? '暂停播放' : '开始播放'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(176, 56),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 20),
              IconButton.filledTonal(
                tooltip: '下一首',
                onPressed: ref.watch(playbackQueueProvider).tracks.length > 1
                    ? () => _playSibling(ref)
                    : null,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            player.error?.message ?? _statusText(player.status),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: player.error == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.error,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _playSibling(WidgetRef ref, {bool previous = false}) async {
    final queue = ref.read(playbackQueueProvider.notifier);
    final track = previous ? queue.selectPrevious() : queue.selectNext();
    if (track != null) await ref.read(playerProvider.notifier).playTrack(track);
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) => Center(
        key: const ValueKey('lyrics-panel'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 54,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                track.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '暂无可用歌词',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '歌词数据服务将在后续任务接入；届时会优先显示本地 LRC。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
}

class _NothingPlaying extends StatelessWidget {
  const _NothingPlaying();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.album_outlined, size: 56),
              const SizedBox(height: 16),
              Text('还没有正在播放的歌曲', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('从排行榜、搜索或列表选择一首歌后，可在这里查看详情。'),
            ],
          ),
        ),
      );
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 336),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .28),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: ClipOval(
                  child: track.coverUri == null
                      ? Icon(
                          Icons.music_note,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : Image.network(
                          track.coverUri.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.music_note,
                            size: 96,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
}

String _duration(Duration? value) {
  if (value == null) return '--:--';
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _statusText(AudioEngineStatus status) => switch (status) {
      AudioEngineStatus.loading => '正在加载音频',
      AudioEngineStatus.playing => '正在播放',
      AudioEngineStatus.paused || AudioEngineStatus.ready => '已暂停',
      AudioEngineStatus.completed => '播放完成',
      AudioEngineStatus.error => '播放失败',
      AudioEngineStatus.idle => '准备播放',
    };
