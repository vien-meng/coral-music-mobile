import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
import '../state/leaderboard_controller.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(leaderboardProvider.notifier).loadInitial(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaderboardProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(state: state),
        if (state.boards.isNotEmpty) _BoardSelector(state: state),
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!.message),
            actions: [
              TextButton(
                onPressed: () =>
                    ref.read(leaderboardProvider.notifier).refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        Expanded(child: _Content(state: state)),
        if (state.tracks.isNotEmpty) _Pagination(state: state),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(
          children: [
            DropdownButton<OnlineSource>(
              value: state.source,
              items: const [
                DropdownMenuItem(
                  value: OnlineSource.kuwo,
                  child: Text('酷我音乐'),
                ),
                DropdownMenuItem(
                  value: OnlineSource.qq,
                  child: Text('QQ音乐'),
                ),
              ],
              onChanged: state.isLoading
                  ? null
                  : (source) {
                      if (source != null) {
                        ref
                            .read(leaderboardProvider.notifier)
                            .selectSource(source);
                      }
                    },
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: state.tracks.isEmpty
                  ? null
                  : () async {
                      ref.read(playbackQueueProvider.notifier).replaceQueue(
                            state.tracks,
                            contextId:
                                'leaderboard:${state.activeBoard?.id}:${state.page}',
                          );
                      await ref
                          .read(playerProvider.notifier)
                          .playTrack(state.tracks.first);
                    },
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放全部'),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: state.isLoading
                  ? null
                  : () => ref.read(leaderboardProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
}

class _BoardSelector extends ConsumerWidget {
  const _BoardSelector({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        height: 48,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          scrollDirection: Axis.horizontal,
          itemCount: state.boards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final board = state.boards[index];
            return ChoiceChip(
              label: Text(board.name),
              selected: state.activeBoard?.id == board.id,
              onSelected: state.isLoading
                  ? null
                  : (_) =>
                      ref.read(leaderboardProvider.notifier).selectBoard(board),
            );
          },
        ),
      );
}

class _Content extends ConsumerWidget {
  const _Content({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.tracks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.tracks.isEmpty) {
      return Center(
        child: Text(state.error == null ? '暂无歌曲' : '加载失败，请重试'),
      );
    }
    return RefreshIndicator(
      onRefresh: ref.read(leaderboardProvider.notifier).refresh,
      child: ListView.separated(
        key: const Key('leaderboard-tracks'),
        itemCount: state.tracks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final track = state.tracks[index];
          return ListTile(
            leading: _Cover(uri: track.coverUri),
            title:
                Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              track.artist.isEmpty ? '未知歌手' : track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(_duration(track.duration)),
            onTap: () async {
              ref.read(playbackQueueProvider.notifier).replaceQueue(
                    state.tracks,
                    startIndex: index,
                    contextId:
                        'leaderboard:${state.activeBoard?.id}:${state.page}',
                  );
              await ref.read(playerProvider.notifier).playTrack(track);
            },
          );
        },
      ),
    );
  }

  static String _duration(Duration? duration) {
    if (duration == null) return '';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const SizedBox.square(
        dimension: 48,
        child: Icon(Icons.music_note),
      ),
    );
    if (uri == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        uri.toString(),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一页',
              onPressed: state.hasPrevious && !state.isLoading
                  ? ref.read(leaderboardProvider.notifier).previousPage
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('第 ${state.page} 页 · 共 ${state.total} 首'),
            IconButton(
              tooltip: '下一页',
              onPressed: state.hasNext && !state.isLoading
                  ? ref.read(leaderboardProvider.notifier).nextPage
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      );
}
