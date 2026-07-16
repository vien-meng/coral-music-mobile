import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final colors = Theme.of(context).colorScheme;
    if (track?.id != _favoriteTrackId) {
      _favoriteTrackId = track?.id;
      _favorite = track == null
          ? null
          : ref.read(libraryProvider.notifier).isFavorite(track.id);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('播放详情'),
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
    final mode = ref.watch(
      playbackQueueProvider.select((queue) => queue.mode),
    );
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
          Row(
            children: [
              const Icon(Icons.volume_up_outlined),
              Expanded(
                child: Semantics(
                  label: '播放音量',
                  value: '${(player.volume * 100).round()}%',
                  child: Slider(
                    value: player.volume,
                    onChanged: ref.read(playerProvider.notifier).setVolume,
                  ),
                ),
              ),
            ],
          ),
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
                tooltip: _playbackModeLabel(mode),
                onPressed: ref.read(playbackQueueProvider.notifier).cycleMode,
                icon: Icon(_playbackModeIcon(mode)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => ref
                    .read(playerProvider.notifier)
                    .setSpeed(_nextPlaybackSpeed(player.speed)),
                child: Text(
                    '${player.speed.toStringAsFixed(player.speed % 1 == 0 ? 0 : 2)}x'),
              ),
              const SizedBox(width: 8),
              if (track.availableQualities.isNotEmpty) ...[
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(_qualityLabel(player.quality)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 80),
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
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: isActive ? FontWeight.bold : null,
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
