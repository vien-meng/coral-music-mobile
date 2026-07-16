import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../domain/music.dart';
import '../../library/state/library_controller.dart';
import '../data/audio_engine.dart';
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
  String? _favoriteTrackId;
  Future<bool>? _favorite;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final queueTrack = ref.watch(
      playbackQueueProvider.select((queue) => queue.currentTrack),
    );
    final track = player.track ?? queueTrack;
    if (track?.id != _favoriteTrackId) {
      _favoriteTrackId = track?.id;
      _favorite = track == null
          ? null
          : ref.read(libraryProvider.notifier).isFavorite(track.id);
    }

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
          if (track != null)
            FutureBuilder<bool>(
              future: _favorite,
              builder: (context, snapshot) => IconButton(
                tooltip: snapshot.data == true ? '取消收藏' : '收藏歌曲',
                onPressed: snapshot.connectionState != ConnectionState.done
                    ? null
                    : () async {
                        final favorite = await ref
                            .read(libraryProvider.notifier)
                            .toggleFavorite(track);
                        if (!mounted) return;
                        setState(() => _favorite = Future.value(favorite));
                      },
                icon: Icon(
                  snapshot.data == true
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
              ),
            ),
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
                height: 2,
                decoration: const BoxDecoration(
                  color: CoralPalette.mint,
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
                          leading: Icon(
                            isCurrent
                                ? Icons.graphic_eq
                                : Icons.music_note_outlined,
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
      padding: const EdgeInsets.fromLTRB(24, 98, 24, 36),
      child: Column(
        children: [
          _AlbumArtwork(track: track),
          const SizedBox(height: 28),
          Text(
            track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            track.artist.isEmpty ? '未知歌手' : track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 26),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: CoralPalette.player,
              inactiveTrackColor: CoralPalette.lilac.withValues(alpha: .45),
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
                tooltip: _playbackModeLabel(mode),
                onPressed: ref.read(playbackQueueProvider.notifier).cycleMode,
                icon: Icon(_playbackModeIcon(mode)),
              ),
              const SizedBox(width: 14),
              IconButton(
                tooltip: '上一首',
                onPressed: queue.tracks.length > 1
                    ? () => _playSibling(ref, previous: true)
                    : null,
                icon: const Icon(Icons.skip_previous_rounded, size: 32),
              ),
              const SizedBox(width: 18),
              SizedBox.square(
                dimension: 70,
                child: FilledButton(
                  key: const Key('player-detail-toggle'),
                  onPressed: () =>
                      ref.read(playerProvider.notifier).toggle(track),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                    backgroundColor: CoralPalette.player,
                    foregroundColor: Colors.white,
                  ),
                  child: Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              IconButton(
                tooltip: '下一首',
                onPressed:
                    queue.tracks.length > 1 ? () => _playSibling(ref) : null,
                icon: const Icon(Icons.skip_next_rounded, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 22),
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
                onTap: () => _showVolumeSheet(context, ref, player.volume),
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

  void _showVolumeSheet(BuildContext context, WidgetRef ref, double value) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
        child: Row(
          children: [
            const Icon(Icons.volume_up_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                label: '播放音量',
                value: '${(value * 100).round()}%',
                child: Slider(
                  value: value,
                  onChanged: ref.read(playerProvider.notifier).setVolume,
                ),
              ),
            ),
          ],
        ),
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
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
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

class _LyricsPanel extends ConsumerStatefulWidget {
  const _LyricsPanel({required this.track});

  final Track track;

  @override
  ConsumerState<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<_LyricsPanel> {
  final _scrollController = ScrollController();
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
      error: (_, __) => const Center(child: Text('歌词加载失败')),
      data: (payload) {
        final lines =
            payload == null ? const <LyricLine>[] : parseLyricTimeline(payload);
        if (lines.isEmpty) return _LyricEmpty(track: track);
        var active = 0;
        for (var index = 0; index < lines.length; index++) {
          if (lines[index].at <= position) active = index;
        }
        if (active != _activeLine) {
          _activeLine = active;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrollController.hasClients) return;
            // ponytail: estimated line height; switch to measured keys only if lyric layouts drift visibly.
            final target = (active * 82.0).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );
            _scrollController.animateTo(
              target,
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
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text.rich(
                    line.words.isEmpty
                        ? TextSpan(text: line.text)
                        : TextSpan(
                            children: line.words.map((word) {
                              final wordActive = position >= word.start &&
                                  position < word.start + word.duration;
                              return TextSpan(
                                text: word.text,
                                style: wordActive
                                    ? const TextStyle(
                                        fontWeight: FontWeight.bold)
                                    : null,
                              );
                            }).toList(growable: false),
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LyricEmpty extends StatelessWidget {
  const _LyricEmpty({required this.track});

  final Track track;

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
          ],
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
        constraints: const BoxConstraints(maxWidth: 322),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(42),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CoralPalette.sky,
                  CoralPalette.periwinkle,
                  CoralPalette.pink
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .74)),
              boxShadow: [
                BoxShadow(
                  color: CoralPalette.player.withValues(alpha: .2),
                  blurRadius: 36,
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
                padding: const EdgeInsets.all(16),
                child: ClipOval(
                  child: track.coverUri == null
                      ? Icon(
                          Icons.music_note_rounded,
                          size: 104,
                          color: CoralPalette.player,
                        )
                      : Image.network(
                          track.coverUri.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.music_note_rounded,
                            size: 104,
                            color: CoralPalette.player,
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
      AudioQuality.flac24bit => '24bit FLAC',
      AudioQuality.flac => 'FLAC',
      AudioQuality.high320k => '320k',
      AudioQuality.high192k => '192k',
      AudioQuality.standard128k => '128k',
    };
