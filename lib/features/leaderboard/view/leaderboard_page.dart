import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/cover_image.dart';
import '../../../app/online_source_menu.dart';
import '../../../app/app_theme.dart';
import '../../../domain/music.dart';
import '../../download/view/download_track_button.dart';
import '../../library/data/library_store.dart';
import '../../library/view/favorite_track_button.dart';
import '../../library/view/playlist_picker.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
import '../../player/state/user_api_debug_controller.dart';
import '../../song_list/state/song_list_controller.dart';
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
        () => ref.read(leaderboardProvider.notifier).loadInitial());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaderboardProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              _TopBar(state: state),
              const SizedBox(height: 18),
              _DiscoveryHero(state: state),
              const SizedBox(height: 16),
              _QuickActions(
                onDailyRecommendation: _loadDailyRecommendation,
                onRadio: _startRadio,
                onSongList: _openSongList,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: CoralPalette.mint,
            onRefresh: ref.read(leaderboardProvider.notifier).refresh,
            child: ListView(
              key: const Key('leaderboard-tracks'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              children: [
                _SectionHeader(
                  title: '推荐歌单',
                  trailing: state.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton.icon(
                          onPressed: () =>
                              ref.read(leaderboardProvider.notifier).refresh(),
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('换一换'),
                        ),
                ),
                const SizedBox(height: 8),
                if (state.boards.isEmpty && state.isLoading)
                  const _BoardLoading()
                else if (state.boards.isNotEmpty)
                  _BoardStrip(state: state)
                else
                  _InlineMessage(message: state.error?.message ?? '暂无可用榜单'),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: state.activeBoard?.name ?? '热门歌曲',
                  subtitle:
                      state.activeBoard == null ? null : '${state.total} 首歌曲',
                  trailing: OutlinedButton.icon(
                    onPressed:
                        state.tracks.isEmpty ? null : () => _playAll(state),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('播放全部'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (state.error != null)
                  _ErrorCard(
                    message: state.error!.message,
                    onRetry: ref.read(leaderboardProvider.notifier).refresh,
                  )
                else if (state.isLoading && state.tracks.isEmpty)
                  const _TrackLoading()
                else if (state.tracks.isEmpty)
                  const _InlineMessage(message: '这里暂时没有歌曲')
                else
                  for (var index = 0; index < state.tracks.length; index++)
                    _TrackTile(
                      track: state.tracks[index],
                      rank: index + 1,
                      onTap: () => _playTrack(state, index),
                    ),
                if (state.tracks.isNotEmpty) _Pagination(state: state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _playAll(LeaderboardState state) async {
    final tracks =
        await ref.read(libraryStoreProvider).filterIgnored(state.tracks);
    if (tracks.isEmpty) return;
    ref.read(playbackQueueProvider.notifier).replaceQueue(
          tracks,
          contextId: 'leaderboard:${state.activeBoard?.id}:${state.page}',
        );
    await ref.read(playerProvider.notifier).playTrack(tracks.first);
  }

  Future<void> _playTrack(LeaderboardState state, int index) async {
    final track = state.tracks[index];
    ref.read(playbackQueueProvider.notifier).replaceQueue(
          state.tracks,
          startIndex: index,
          contextId: 'leaderboard:${state.activeBoard?.id}:${state.page}',
        );
    await ref.read(playerProvider.notifier).playTrack(track);
  }

  Future<void> _loadDailyRecommendation() async {
    if (ref.read(leaderboardProvider).isLoading) {
      _showMessage('推荐内容正在加载');
      return;
    }
    final board =
        await ref.read(leaderboardProvider.notifier).loadDailyRecommendation();
    if (!mounted) return;
    final error = ref.read(leaderboardProvider).error;
    _showMessage(
        board == null ? error?.message ?? '暂无每日推荐' : '今日推荐：${board.name}');
  }

  Future<void> _startRadio() async {
    var state = ref.read(leaderboardProvider);
    if (state.isLoading) {
      _showMessage('推荐内容正在加载');
      return;
    }
    if (state.tracks.isEmpty) {
      await ref.read(leaderboardProvider.notifier).loadDailyRecommendation();
      state = ref.read(leaderboardProvider);
    }
    final tracks =
        await ref.read(libraryStoreProvider).filterIgnored(state.tracks);
    if (!mounted) return;
    if (tracks.isEmpty) {
      _showMessage(state.error?.message ?? '暂无可播放的电台歌曲');
      return;
    }
    final queue = ref.read(playbackQueueProvider.notifier);
    queue
      ..replaceQueue(
        tracks,
        contextId: 'radio:${state.source.id}:${state.activeBoard?.id}',
      )
      ..setMode(PlaybackMode.shuffle);
    final track =
        queue.selectNext() ?? ref.read(playbackQueueProvider).currentTrack;
    if (track == null) return;
    await ref.read(playerProvider.notifier).playTrack(track);
    if (mounted) _showMessage('音乐电台已开始随机播放');
  }

  void _openSongList() {
    ref.read(songListProvider.notifier).closeDetail();
    context.go('/song-list');
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const candidates = [
      OnlineSource.kuwo,
      OnlineSource.kugou,
      OnlineSource.qq,
      OnlineSource.migu,
      OnlineSource.netease,
    ];
    final supported = ref.watch(userApiDebugProvider.select((userApi) =>
        userApi.activeSource?.musicUrlSources ?? const <String>{}));
    return Row(
      children: [
        Text('发现',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                )),
        const Spacer(),
        OnlineSourceMenu(
          activeSource: state.source,
          isLoading: state.isLoading,
          sources: supportedOnlineSources(candidates, supported),
          onSelected: ref.read(leaderboardProvider.notifier).selectSource,
        ),
        const _NotificationMenu(),
      ],
    );
  }
}

class _NotificationMenu extends StatelessWidget {
  const _NotificationMenu();

  @override
  Widget build(BuildContext context) => MenuAnchor(
        style: onlineSourceMenuStyle(context),
        menuChildren: [
          const OnlineSourceMenuHeading(title: '消息通知'),
          SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 30,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '暂无新消息',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
        builder: (context, controller, _) => IconButton(
          tooltip: '通知',
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(
            Icons.notifications_none_outlined,
            color: controller.isOpen
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onDailyRecommendation,
    required this.onRadio,
    required this.onSongList,
  });

  final VoidCallback onDailyRecommendation;
  final VoidCallback onRadio;
  final VoidCallback onSongList;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _QuickAction(
            icon: Icons.play_circle_outline,
            label: '每日推荐',
            onTap: onDailyRecommendation,
          ),
          _QuickAction(
            icon: Icons.grid_view_outlined,
            label: '歌单广场',
            onTap: onSongList,
          ),
          _QuickAction(
            icon: Icons.radio_rounded,
            label: '音乐电台',
            onTap: onRadio,
          ),
          _QuickAction(
            icon: Icons.category_outlined,
            label: '音乐分类',
            onTap: () => context.go('/library'),
          ),
        ],
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: CoralPalette.brand),
                const SizedBox(height: 6),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      );
}

class _DiscoveryHero extends StatelessWidget {
  const _DiscoveryHero({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context) {
    final board = state.activeBoard?.name ?? '今日推荐';
    return Container(
      height: 106,
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xffffeee9), Color(0xfffff8f5)],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomRight,
            child: _HeroArtwork(
                uri: state.tracks.isEmpty ? null : state.tracks.first.coverUri),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('春日初遇',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: CoralPalette.brand,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 4),
              Text(
                board,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text('温柔旋律陪你度过今天',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .74),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 34,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CoverImage(
        uri: uri,
        fallback: fallback,
        width: 78,
        height: 78,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class _BoardStrip extends ConsumerWidget {
  const _BoardStrip({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        height: 142,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: state.boards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final board = state.boards[index];
            final selected = state.activeBoard?.id == board.id;
            return SizedBox(
              width: 108,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: state.isLoading
                      ? null
                      : () => ref
                          .read(leaderboardProvider.notifier)
                          .selectBoard(board),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BoardCover(
                          uri: state.tracks.isEmpty
                              ? null
                              : state
                                  .tracks[index % state.tracks.length].coverUri,
                          index: index,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          board.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _BoardCover extends StatelessWidget {
  const _BoardCover({required this.uri, required this.index});

  final Uri? uri;
  final int index;

  @override
  Widget build(BuildContext context) {
    const colors = [
      CoralPalette.sky,
      CoralPalette.pink,
      CoralPalette.peach,
      CoralPalette.cyan
    ];
    final fallback = Container(
      width: double.infinity,
      height: 74,
      decoration: BoxDecoration(
        color: colors[index % colors.length],
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        [
          Icons.auto_awesome_rounded,
          Icons.local_fire_department_rounded,
          Icons.nightlight_round,
          Icons.favorite_rounded
        ][index % 4],
        size: 24,
        color: Colors.white,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: CoverImage(
          uri: uri,
          fallback: fallback,
          width: double.infinity,
          height: 74,
          fit: BoxFit.cover),
    );
  }
}

class _TrackTile extends ConsumerWidget {
  const _TrackTile(
      {required this.track, required this.rank, required this.onTap});

  final Track track;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 25,
                    child: Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: rank <= 3
                                ? CoralPalette.player
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  _TrackArtwork(uri: track.coverUri),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                          track.artist.isEmpty ? '未知歌手' : track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(_duration(track.duration),
                      style: Theme.of(context).textTheme.labelSmall),
                  FavoriteTrackButton(track: track),
                  DownloadTrackButton(track: track),
                  IconButton(
                    tooltip: '添加到我的列表',
                    onPressed: () => addTrackToPlaylist(context, ref, track),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  static String _duration(Duration? duration) {
    if (duration == null) return '';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _TrackArtwork extends StatelessWidget {
  const _TrackArtwork({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        color: CoralPalette.sky,
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CoverImage(
        uri: uri,
        fallback: placeholder,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _BoardLoading extends StatelessWidget {
  const _BoardLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 116,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _TrackLoading extends StatelessWidget {
  const _TrackLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        color:
            Theme.of(context).colorScheme.errorContainer.withValues(alpha: .58),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
              TextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一页',
              onPressed: state.hasPrevious && !state.isLoading
                  ? ref.read(leaderboardProvider.notifier).previousPage
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text('第 ${state.page} 页 · 共 ${state.total} 首'),
            IconButton(
              tooltip: '下一页',
              onPressed: state.hasNext && !state.isLoading
                  ? ref.read(leaderboardProvider.notifier).nextPage
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );
}
