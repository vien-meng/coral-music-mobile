import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/playback_queue_controller.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playbackQueueProvider.select((queue) => queue.currentTrack),
    );
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.music_note)),
          title: Text(track?.title ?? '未在播放'),
          subtitle: Text(
            track == null
                ? '从排行榜、搜索或列表选择歌曲'
                : '${track.artist.isEmpty ? '未知歌手' : track.artist} · 待接入音频引擎',
          ),
          trailing: const IconButton(
            tooltip: '音频引擎将在播放器阶段接入',
            onPressed: null,
            icon: Icon(Icons.play_arrow),
          ),
        ),
      ),
    );
  }
}
