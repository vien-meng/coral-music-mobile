import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../app/audio_quality_labels.dart';
import '../../../app/cover_image.dart';
import '../../../domain/music.dart';
import '../../library/data/library_store.dart';
import '../../library/view/favorite_track_button.dart';
import '../data/audio_engine.dart';
import '../data/audio_file_probe.dart';
import '../state/playback_queue_controller.dart';
import '../state/player_controller.dart';
import 'player_action_sheets.dart';
import 'player_transport_controls.dart';

class PlayerControlsPanel extends ConsumerWidget {
  const PlayerControlsPanel({
    required this.track,
    required this.player,
    super.key,
  });

  final Track track;
  final PlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(playbackQueueProvider.select((queue) => queue.mode));

    return SingleChildScrollView(
      key: const ValueKey('player-panel'),
      physics: const AlwaysScrollableScrollPhysics(),
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
          PlayerTransportControls(
            track: track,
            player: player,
            toggleKey: const Key('player-detail-toggle'),
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
                  SizedBox(
                    height: 48,
                    child: FavoriteTrackButton(track: track),
                  ),
                  const SizedBox(height: 3),
                  Text('收藏', style: Theme.of(context).textTheme.labelSmall),
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
                        content: Text(
                          ignored ? '已不感兴趣，播放全部会跳过此曲' : '已恢复此曲',
                        ),
                      ),
                    );
                  }
                },
              ),
              if (track.sourceKind == TrackSourceKind.online ||
                  track.sourceKind == TrackSourceKind.webdav)
                _PlayerAction(
                  icon: Icons.download_outlined,
                  label: '下载',
                  onTap: () => enqueuePlayerDownload(context, ref, track),
                ),
              _PlayerAction(
                icon: Icons.timer_outlined,
                label: player.stopAfterCurrent ? '播完停止' : '定时停止',
                onTap: () => showPlayerSleepTimerSheet(context, ref),
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
                _SmallControl(
                  label: audioQualityLabel(player.quality),
                  tooltip: '播放音质',
                  onTap: () => showPlayerQualitySheet(
                    context,
                    ref,
                    track,
                    player.quality,
                  ),
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
                    onPressed: () => context.go('/setting/source'),
                    icon: const Icon(Icons.settings_input_component_outlined),
                    label: const Text('去导入音源'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SmallControl extends StatelessWidget {
  const _SmallControl({
    required this.label,
    required this.tooltip,
    this.onTap,
  });

  final String label;
  final String tooltip;
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
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
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
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            width: 48,
            child: IconButton(
              tooltip: label,
              onPressed: onTap,
              icon: Icon(icon, size: 21),
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
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

String _fileInfoText(AudioFileInfo? info, AudioQuality quality) {
  return [
    if (info?.bitrate case final bitrate?) '${(bitrate / 1000).round()} kbps',
    if (info?.sampleRate case final sampleRate?)
      '${(sampleRate / 1000).round()} kHz',
    if (info?.format case final format?) format.toUpperCase(),
    audioQualityLabel(quality),
  ].where((part) => part.isNotEmpty).join(' · ');
}
