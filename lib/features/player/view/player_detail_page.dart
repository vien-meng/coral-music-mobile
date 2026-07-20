import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/cover_image.dart';
import '../../../app/app_theme.dart';
import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../../library/data/library_store.dart';
import '../../library/view/favorite_track_button.dart';
import '../../download/state/download_controller.dart';
import '../data/audio_engine.dart';
import '../data/audio_file_probe.dart';
import '../data/lyric_timeline.dart';
import '../state/lyric_controller.dart';
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PanelTab(
              label: '正在播放',
              selected: _panel == _DetailPanel.player,
              onTap: () => setState(() => _panel = _DetailPanel.player),
            ),
            const SizedBox(width: 18),
            _PanelTab(
              label: '歌词',
              selected: _panel == _DetailPanel.lyrics,
              onTap: () => setState(() => _panel = _DetailPanel.lyrics),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              key: const Key('player-queue-button'),
              tooltip: '播放队列',
              onPressed: Scaffold.of(context).openEndDrawer,
              icon: const Icon(Icons.queue_music),
            ),
          ),
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
      endDrawer: const _PlaybackQueueDrawer(),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: coralPageGradient),
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

class _PanelTab extends StatelessWidget {
  const _PanelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: selected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 16 : 0,
                height: 1,
                decoration: const BoxDecoration(
                  color: CoralPalette.brand,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PlaybackQueueDrawer extends ConsumerWidget {
  const _PlaybackQueueDrawer();

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

class _PlayerPanel extends ConsumerWidget {
  const _PlayerPanel({required this.track, required this.player});

  final Track track;
  final PlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(playbackQueueProvider.select((queue) => queue.mode));
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

    return SingleChildScrollView(
      key: const ValueKey('player-panel'),
      padding: const EdgeInsets.fromLTRB(24, 76, 24, 30),
      child: Column(
        children: [
          _AlbumArtwork(track: track),
          const SizedBox(height: 20),
          Text(
            track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.35,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            [
              track.artist.isEmpty ? '未知歌手' : track.artist,
              if (track.album?.trim().isNotEmpty == true &&
                  track.album!.trim() != track.title.trim())
                track.album!.trim(),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            _fileInfoText(player.fileInfo, player.quality),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: .78),
                ),
          ),
          const SizedBox(height: 20),
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
            mainAxisSize: MainAxisSize.min,
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
                  key: const Key('player-detail-toggle'),
                  onPressed: () =>
                      ref.read(playerProvider.notifier).toggle(track),
                  style: OutlinedButton.styleFrom(
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
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: ref.read(playbackQueueProvider.notifier).cycleMode,
            icon: Icon(_playbackModeIcon(mode), size: 18),
            label: Text(_playbackModeLabel(mode)),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FavoriteTrackButton(track: track),
                  const Text('收藏'),
                ],
              ),
              _PlayerAction(
                icon: Icons.block_outlined,
                label: '不喜欢',
                onTap: () async {
                  final ignored =
                      await ref.read(libraryStoreProvider).toggleIgnored(track);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(ignored ? '已不感兴趣，播放全部会跳过此曲' : '已恢复此曲')),
                    );
                  }
                },
              ),
              if (track.sourceKind == TrackSourceKind.online ||
                  track.sourceKind == TrackSourceKind.webdav)
                _PlayerAction(
                  icon: Icons.download_outlined,
                  label: '下载',
                  onTap: () =>
                      ref.read(downloadProvider.notifier).enqueue(track),
                ),
              _PlayerAction(
                icon: player.volume == 0
                    ? Icons.volume_off_outlined
                    : Icons.volume_up_outlined,
                label: '音量',
                onTap: () => _showVolumeSheet(context, ref),
              ),
              _PlayerAction(
                icon: Icons.timer_outlined,
                label: player.stopAfterCurrent ? '播完停' : '定时',
                onTap: () => _showSleepTimerSheet(context, ref),
              ),
              _PlayerAction(
                icon: Icons.queue_music_outlined,
                label: '列表',
                onTap: Scaffold.of(context).openEndDrawer,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              _SmallControl(
                label:
                    '${player.speed.toStringAsFixed(player.speed % 1 == 0 ? 0 : 2)}x',
                tooltip: '播放倍速',
                onTap: () => ref
                    .read(playerProvider.notifier)
                    .setSpeed(_nextPlaybackSpeed(player.speed)),
              ),
              if (track.availableQualities.isNotEmpty)
                PopupMenuButton<AudioQuality>(
                  tooltip: '播放音质',
                  onSelected: ref.read(playerProvider.notifier).setQuality,
                  itemBuilder: (context) => [
                    for (final quality in track.availableQualities)
                      CheckedPopupMenuItem(
                        value: quality,
                        checked: quality == player.quality,
                        child: Text(_qualityLabel(quality)),
                      ),
                  ],
                  child: _SmallControl(
                      label: _qualityLabel(player.quality), tooltip: '播放音质'),
                ),
              _SmallControl(
                label: '${(player.volume * 100).round()}%',
                icon: Icons.volume_up_outlined,
                tooltip: '播放音量',
                onTap: () => _showVolumeSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            player.error?.message ?? _statusText(player.status),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: player.error == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.error,
                ),
          ),
          if (player.error != null)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: ref.read(playerProvider.notifier).retryCurrent,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试播放'),
                ),
                if (player.error!.message.startsWith('请先在音源管理'))
                  TextButton.icon(
                    onPressed: () => context.push('/setting/source'),
                    icon: const Icon(Icons.settings_input_component_outlined),
                    label: const Text('去导入音源'),
                  ),
              ],
            ),
        ],
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

  void _showVolumeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final volume =
              ref.watch(playerProvider.select((state) => state.volume));
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
            child: Row(
              children: [
                Icon(volume == 0
                    ? Icons.volume_off_outlined
                    : Icons.volume_up_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: '播放音量',
                    value: '${(volume * 100).round()}%',
                    child: Slider(
                      value: volume,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: ref.read(playerProvider.notifier).setVolume,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSleepTimerSheet(BuildContext context, WidgetRef ref) {
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
}

class _SmallControl extends StatelessWidget {
  const _SmallControl(
      {required this.label, required this.tooltip, this.icon, this.onTap});

  final String label;
  final String tooltip;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 4)
                  ],
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PlayerAction extends StatelessWidget {
  const _PlayerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21),
              const SizedBox(height: 3),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
}

class _LyricsPanel extends ConsumerStatefulWidget {
  const _LyricsPanel({required this.track});

  final Track track;

  @override
  ConsumerState<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<_LyricsPanel> {
  final _scrollController = ScrollController();
  final _lineKeys = <int, GlobalKey>{};
  var _activeLine = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final lyric = ref.watch(lyricProvider(track));
    final position =
        ref.watch(playerProvider.select((state) => state.position));
    return lyric.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LyricError(
        message: _lyricErrorMessage(error),
        onRetry: () => ref.invalidate(lyricProvider(track)),
      ),
      data: (payload) {
        final lines =
            payload == null ? const <LyricLine>[] : parseLyricTimeline(payload);
        if (lines.isEmpty) {
          return _LyricEmpty(
            track: track,
            onRetry: () => ref.invalidate(lyricProvider(track)),
          );
        }
        var active = 0;
        for (var index = 0; index < lines.length; index++) {
          if (lines[index].at <= position) active = index;
        }
        if (active != _activeLine) {
          _activeLine = active;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrollController.hasClients) return;
            final targetContext = _lineKeys[active]?.currentContext;
            if (targetContext != null) {
              Scrollable.ensureVisible(
                targetContext,
                alignment: .42,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
              );
              return;
            }
            // ponytail: only used until ListView builds an off-screen active line.
            _scrollController.animateTo(
              (active * 56.0).clamp(
                0.0,
                _scrollController.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
            );
          });
        }
        return ListView.builder(
          key: const ValueKey('lyrics-panel'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(28, 104, 28, 80),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            final isActive = index == active;
            return KeyedSubtree(
              key: _lineKeys.putIfAbsent(index, GlobalKey.new),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text.rich(
                      line.words.isEmpty || !isActive
                          ? TextSpan(text: line.text)
                          : TextSpan(
                              children: line.words
                                  .expand(
                                    (word) => _karaokeWordSpans(
                                      context,
                                      word,
                                      position,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: isActive
                                ? CoralPalette.player
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: .52),
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w500,
                          ),
                    ),
                    if (line.translation case final translation?)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          translation,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                    if (line.romanization case final romanization?)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          romanization,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

List<TextSpan> _karaokeWordSpans(
  BuildContext context,
  LyricWord word,
  Duration position,
) {
  final elapsed = position - word.start;
  final duration = word.duration.inMilliseconds;
  final progress = elapsed.inMilliseconds <= 0
      ? 0.0
      : (elapsed.inMilliseconds / (duration == 0 ? 1 : duration))
          .clamp(0.0, 1.0);
  final characters = word.text.runes.map(String.fromCharCode).toList();
  if (characters.isEmpty) return const [];
  final filled = progress * characters.length;
  final muted =
      Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .62);
  return List.generate(characters.length, (index) {
    final characterProgress = (filled - index).clamp(0.0, 1.0);
    return TextSpan(
      text: characters[index],
      style: TextStyle(
        color: Color.lerp(muted, CoralPalette.player, characterProgress),
        fontWeight: characterProgress > 0 ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  });
}

class _LyricEmpty extends StatelessWidget {
  const _LyricEmpty({required this.track, required this.onRetry});

  final Track track;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(track.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('暂无可用歌词'),
            const SizedBox(height: 6),
            const Text('当前音源未提供可用歌词'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载歌词'),
            ),
          ],
        ),
      );
}

class _LyricError extends StatelessWidget {
  const _LyricError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lyrics_outlined, size: 44),
              const SizedBox(height: 12),
              const Text('歌词加载失败'),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新加载歌词'),
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Icon(
      Icons.music_note_rounded,
      size: 104,
      color: scheme.onSurface.withValues(alpha: .56),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: CoralPalette.brand.withValues(alpha: .08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CoverImage(
              uri: track.coverUri,
              fallback: ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(child: fallback),
              ),
            ),
          ),
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

String _playbackModeLabel(PlaybackMode mode) => switch (mode) {
      PlaybackMode.listLoop => '列表循环',
      PlaybackMode.singleLoop => '单曲循环',
      PlaybackMode.shuffle => '随机播放',
    };

IconData _playbackModeIcon(PlaybackMode mode) => switch (mode) {
      PlaybackMode.listLoop => Icons.repeat,
      PlaybackMode.singleLoop => Icons.repeat_one,
      PlaybackMode.shuffle => Icons.shuffle,
    };

double _nextPlaybackSpeed(double current) {
  const values = [.5, .75, 1.0, 1.25, 1.5, 2.0];
  final currentIndex =
      values.indexWhere((value) => (value - current).abs() < .01);
  return values[(currentIndex + 1) % values.length];
}

String _qualityLabel(AudioQuality quality) => switch (quality) {
      AudioQuality.master => '臻品母带',
      AudioQuality.atmosPlus => '臻品全景声',
      AudioQuality.atmos => '全景声',
      AudioQuality.hires => 'Hi-Res',
      AudioQuality.flac24bit => 'Hi-Res 24bit',
      AudioQuality.flac => 'SQ',
      AudioQuality.high320k => 'HQ',
      AudioQuality.high192k => '192k',
      AudioQuality.standard128k => '128k',
    };

String _fileInfoText(AudioFileInfo? info, AudioQuality quality) {
  return [
    if (info?.bitrate case final bitrate?) '${(bitrate / 1000).round()} kbps',
    if (info?.sampleRate case final sampleRate?)
      '${(sampleRate / 1000).round()} kHz',
    if (info?.format case final format?) format.toUpperCase(),
    _qualityLabel(quality),
  ].where((part) => part.isNotEmpty).join(' · ');
}

String _lyricErrorMessage(Object error) =>
    error is AppFailure ? error.message : '音源未返回可用歌词';
