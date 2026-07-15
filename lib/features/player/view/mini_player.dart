import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/audio_engine.dart';
import '../state/playback_queue_controller.dart';
import '../state/player_controller.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playbackQueueProvider.select((queue) => queue.currentTrack),
    );
    final player = ref.watch(playerProvider);
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: () => context.push('/player'),
              leading: const CircleAvatar(child: Icon(Icons.music_note)),
              title: Text(track?.title ?? '未在播放'),
              subtitle: Text(
                track == null
                    ? '从排行榜、搜索或列表选择歌曲'
                    : player.error?.message ??
                        '${track.artist.isEmpty ? '未知歌手' : track.artist} · ${_statusText(player.status)}',
              ),
              trailing: IconButton(
                tooltip: player.isPlaying ? '暂停' : '播放',
                onPressed: track == null
                    ? null
                    : () => ref.read(playerProvider.notifier).toggle(track),
                icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
            ),
            if (player.track?.id == track?.id && player.duration != null)
              Slider(
                value: player.position.inMilliseconds
                    .clamp(0, player.duration!.inMilliseconds)
                    .toDouble(),
                max: player.duration!.inMilliseconds.toDouble(),
                onChanged: (value) => ref
                    .read(playerProvider.notifier)
                    .seek(Duration(milliseconds: value.round())),
              ),
          ],
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
