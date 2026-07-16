import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../domain/music.dart';
import '../../library/view/playlist_picker.dart';
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
        () => ref.read(leaderboardProvider.notifier).loadInitial());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaderboardProvider);
    return RefreshIndicator(
      color: CoralPalette.mint,
      onRefresh: ref.read(leaderboardProvider.notifier).refresh,
      child: ListView(
        key: const Key('leaderboard-tracks'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        children: [
          _TopBar(isLoading: state.isLoading),
          const SizedBox(height: 14),
          _SourceSelector(state: state),
          const SizedBox(height: 14),
          _DiscoveryHero(state: state),
          const SizedBox(height: 22),
          _SectionHeader(
            title: '精选榜单',
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
          const SizedBox(height: 24),
          _SectionHeader(
            title: state.activeBoard?.name ?? '热门歌曲',
            subtitle: state.activeBoard == null ? null : '${state.total} 首歌曲',
            trailing: FilledButton.icon(
              onPressed: state.tracks.isEmpty ? null : () => _playAll(state),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('播放全部'),
              style: FilledButton.styleFrom(
                backgroundColor: CoralPalette.mint,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
    );
  }

  Future<void> _playAll(LeaderboardState state) async {
    ref.read(playbackQueueProvider.notifier).replaceQueue(
          state.tracks,
          contextId: 'leaderboard:${state.activeBoard?.id}:${state.page}',
        );
    await ref.read(playerProvider.notifier).playTrack(state.tracks.first);
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            '推荐',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                ),
          ),
          const SizedBox(width: 18),
          Text('发现', style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          IconButton(
            tooltip: '通知',
            onPressed: isLoading ? null : () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      );
}

class _SourceSelector extends ConsumerWidget {
  const _SourceSelector({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        height: 37,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: const [
            OnlineSource.kuwo,
            OnlineSource.qq,
            OnlineSource.migu,
            OnlineSource.netease,
          ].length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            const sources = [
              OnlineSource.kuwo,
              OnlineSource.qq,
              OnlineSource.migu,
              OnlineSource.netease,
            ];
            final source = sources[index];
            final selected = state.source == source;
            return ChoiceChip(
              label: Text(source.label),
              selected: selected,
              selectedColor: CoralPalette.mint.withValues(alpha: .18),
              labelStyle: TextStyle(
                color: selected
                    ? CoralPalette.player
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected
                      ? CoralPalette.mint.withValues(alpha: .42)
                      : Theme.of(context).dividerColor,
                ),
              ),
              onSelected: state.isLoading
                  ? null
                  : (_) => ref
                      .read(leaderboardProvider.notifier)
                      .selectSource(source),
            );
          },
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
      height: 174,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffb7ecf2), Color(0xffc9d7ff), Color(0xffffd7ee)],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22284491), blurRadius: 22, offset: Offset(0, 10)),
        ],
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
              const Text('Coral Music · Free',
                  style: TextStyle(color: Color(0xff6c7290))),
              const Spacer(),
              Text(
                board,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: CoralPalette.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              const Text('让喜欢的旋律，陪你度过今天',
                  style: TextStyle(color: Color(0xff636985))),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .8),
                  foregroundColor: CoralPalette.player,
                  minimumSize: const Size(94, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: null,
                child: const Text('正在聆听'),
              ),
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
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: Colors.white.withValues(alpha: .4),
        border: Border.all(color: Colors.white.withValues(alpha: .7)),
      ),
      child:
          const Icon(Icons.music_note_rounded, color: Colors.white, size: 64),
    );
    if (uri == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: Image.network(
        uri.toString(),
        width: 116,
        height: 116,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
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
        height: 116,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: state.boards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final board = state.boards[index];
            final selected = state.activeBoard?.id == board.id;
            return SizedBox(
              width: 128,
              child: Material(
                color: selected
                    ? CoralPalette.mint.withValues(alpha: .12)
                    : Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: .82),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: state.isLoading
                      ? null
                      : () => ref
                          .read(leaderboardProvider.notifier)
                          .selectBoard(board),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BoardMark(index: index),
                        const Spacer(),
                        Text(
                          board.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w800
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

class _BoardMark extends StatelessWidget {
  const _BoardMark({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const colors = [
      CoralPalette.sky,
      CoralPalette.pink,
      CoralPalette.peach,
      CoralPalette.cyan
    ];
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
          color: colors[index % colors.length], shape: BoxShape.circle),
      child: Icon(
        [
          Icons.auto_awesome_rounded,
          Icons.local_fire_department_rounded,
          Icons.nightlight_round,
          Icons.favorite_rounded
        ][index % 4],
        size: 20,
        color: Colors.white,
      ),
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
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.all(Radius.circular(14)),
        gradient: LinearGradient(
            colors: [CoralPalette.periwinkle, CoralPalette.lilac]),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    );
    if (uri == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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
