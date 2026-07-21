import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/cover_image.dart';
import '../../../app/online_source_menu.dart';
import '../../../domain/music.dart';
import '../../library/view/favorite_track_button.dart';
import '../../library/view/playlist_picker.dart';
import '../../library/data/library_store.dart';
import '../../download/state/download_controller.dart';
import '../../download/view/download_track_button.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
import '../../player/state/user_api_debug_controller.dart';
import '../state/song_list_controller.dart';

class SongListPage extends ConsumerStatefulWidget {
  const SongListPage({super.key});

  @override
  ConsumerState<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends ConsumerState<SongListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(songListProvider.notifier).loadInitial());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(songListProvider);
    return state.detail == null
        ? _PlaylistSquare(state: state)
        : _PlaylistDetail(detail: state.detail!);
  }
}

class _PlaylistSquare extends ConsumerWidget {
  const _PlaylistSquare({required this.state});

  final SongListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(songListTagsProvider);
    const candidates = [
      OnlineSource.kuwo,
      OnlineSource.qq,
      OnlineSource.migu,
    ];
    final supported = ref.watch(userApiDebugProvider.select((userApi) =>
        userApi.activeSource?.musicUrlSources ?? const <String>{}));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Text('歌单广场', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              OnlineSourceMenu(
                activeSource: state.source,
                isLoading: state.isLoading,
                sources: supportedOnlineSources(candidates, supported),
                onSelected: ref.read(songListProvider.notifier).selectSource,
              ),
              PopupMenuButton<String>(
                enabled: !state.isLoading,
                tooltip: '歌单排序',
                onSelected: ref.read(songListProvider.notifier).selectSort,
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'hot',
                    checked: state.sortId == 'hot',
                    child: const Text('最热'),
                  ),
                  CheckedPopupMenuItem(
                    value: 'new',
                    checked: state.sortId == 'new',
                    child: const Text('最新'),
                  ),
                ],
                icon: const Icon(Icons.sort_outlined),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: state.isLoading
                    ? null
                    : ref.read(songListProvider.notifier).refresh,
                icon: const Icon(Icons.refresh_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            textInputAction: TextInputAction.search,
            onSubmitted: ref.read(songListProvider.notifier).submitSearch,
            decoration: InputDecoration(
              hintText: '搜索歌单（清空并搜索可返回广场）',
              prefixIcon: Icon(Icons.search_outlined),
              isDense: true,
            ),
          ),
        ),
        tags.when(
          loading: () => const SizedBox(height: 36),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) => SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('热门'),
                  selected: state.selectedTagId == null,
                  selectedColor: Colors.transparent,
                  labelStyle: TextStyle(
                    color: state.selectedTagId == null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: state.selectedTagId == null
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: state.selectedTagId == null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  onSelected: state.isLoading
                      ? null
                      : (_) =>
                          ref.read(songListProvider.notifier).selectTag(null),
                ),
                for (final tag in items) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(tag.name),
                    selected: state.selectedTagId == tag.id,
                    selectedColor: Colors.transparent,
                    labelStyle: TextStyle(
                      color: state.selectedTagId == tag.id
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: state.selectedTagId == tag.id
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: state.selectedTagId == tag.id
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    onSelected: state.isLoading
                        ? null
                        : (_) => ref
                            .read(songListProvider.notifier)
                            .selectTag(tag.id),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!.message),
            actions: [
              TextButton(
                onPressed: state.playlists.isNotEmpty && state.hasNext
                    ? ref.read(songListProvider.notifier).loadMore
                    : ref.read(songListProvider.notifier).refresh,
                child: const Text('重试'),
              ),
            ],
          ),
        Expanded(
          child: state.isLoading && state.playlists.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    final towardEnd = notification is ScrollUpdateNotification
                        ? (notification.scrollDelta ?? 0) > 0
                        : notification is OverscrollNotification &&
                            notification.overscroll > 0;
                    if (towardEnd &&
                        notification.metrics.extentAfter < 320 &&
                        state.hasNext &&
                        !state.isLoading) {
                      unawaited(
                        ref.read(songListProvider.notifier).loadMore(),
                      );
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: ref.read(songListProvider.notifier).refresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 156,
                              mainAxisSpacing: 18,
                              crossAxisSpacing: 14,
                              childAspectRatio: .78,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final playlist = state.playlists[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: state.isLoading
                                      ? null
                                      : () => ref
                                          .read(songListProvider.notifier)
                                          .open(playlist),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child:
                                            _PlaylistCover(playlist: playlist),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        playlist.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        playlist.playCount.isEmpty
                                            ? playlist.author
                                            : '${playlist.playCount} 播放',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                );
                              },
                              childCount: state.playlists.length,
                            ),
                          ),
                        ),
                        if (state.playlists.isNotEmpty)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 56,
                              child: Center(
                                child: state.isLoading
                                    ? const SizedBox.square(
                                        dimension: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : state.hasNext
                                        ? const SizedBox.shrink()
                                        : Text(
                                            '已经到底了',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PlaylistDetail extends ConsumerWidget {
  const _PlaylistDetail({required this.detail});

  final PlaylistDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlaylistDetailBanner(detail: detail),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: detail.tracks.isEmpty
                      ? null
                      : () async {
                          await ref
                              .read(songListProvider.notifier)
                              .resolveTrackArtwork(detail.tracks.first);
                          final queueTracks =
                              ref.read(songListProvider).detail?.tracks ??
                                  detail.tracks;
                          final tracks = await ref
                              .read(libraryStoreProvider)
                              .filterIgnored(queueTracks);
                          if (tracks.isEmpty) return;
                          ref.read(playbackQueueProvider.notifier).replaceQueue(
                                tracks,
                                contextId:
                                    'songlist:${detail.playlist.source.id}:${detail.playlist.id}',
                              );
                          unawaited(
                            ref
                                .read(songListProvider.notifier)
                                .resolveAllTrackArtwork(
                                  ref
                                      .read(playbackQueueProvider.notifier)
                                      .replaceTrack,
                                ),
                          );
                          await ref
                              .read(playerProvider.notifier)
                              .playTrack(tracks.first);
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: Text('播放全部 (${detail.tracks.length})'),
                ),
                FavoriteOnlinePlaylistButton(detail: detail),
                const Spacer(),
                IconButton(
                  tooltip: '下载全部',
                  onPressed: detail.tracks.isEmpty
                      ? null
                      : () async {
                          final result = await ref
                              .read(downloadProvider.notifier)
                              .enqueueAll(detail.tracks);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.skipped == 0
                                    ? '已加入 ${result.added} 首下载任务'
                                    : '已加入 ${result.added} 首，跳过 ${result.skipped} 首重复或不支持歌曲'),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.download_for_offline_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: detail.tracks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final track = detail.tracks[index];
                return ListTile(
                  leading: SizedBox(
                    width: 64,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text('${index + 1}'.padLeft(2, '0')),
                        ),
                        const SizedBox(width: 5),
                        _PlaylistTrackArtwork(
                          uri: track.coverUri ?? detail.playlist.coverUri,
                        ),
                      ],
                    ),
                  ),
                  title: Text(track.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    track.artist.isEmpty ? '未知歌手' : track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FavoriteTrackButton(track: track),
                      DownloadTrackButton(track: track),
                      IconButton(
                        tooltip: '添加到我的列表',
                        onPressed: () =>
                            addTrackToPlaylist(context, ref, track),
                        icon: const Icon(Icons.playlist_add),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await ref
                        .read(songListProvider.notifier)
                        .resolveTrackArtwork(track);
                    final queueTracks =
                        ref.read(songListProvider).detail?.tracks ??
                            detail.tracks;
                    final queueIndex =
                        queueTracks.indexWhere((item) => item.id == track.id);
                    if (queueIndex < 0) return;
                    ref.read(playbackQueueProvider.notifier).replaceQueue(
                          queueTracks,
                          startIndex: queueIndex,
                          contextId:
                              'songlist:${detail.playlist.source.id}:${detail.playlist.id}',
                        );
                    await ref
                        .read(playerProvider.notifier)
                        .playTrack(queueTracks[queueIndex]);
                  },
                );
              },
            ),
          ),
        ],
      );
}

class _PlaylistDetailBanner extends ConsumerWidget {
  const _PlaylistDetailBanner({required this.detail});

  final PlaylistDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emptyCover = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.queue_music_rounded, size: 56),
    );
    return SizedBox(
      height: 224,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverImage(
            uri: detail.playlist.coverUri,
            fit: BoxFit.cover,
            fallback: CoverImage(
              uri: detail.tracks.firstOrNull?.coverUri,
              fit: BoxFit.cover,
              fallback: emptyCover,
            ),
          ),
          const ColoredBox(color: Color(0x66000000)),
          Positioned(
            top: 6,
            left: 6,
            right: 6,
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  color: Colors.white,
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      ref.read(songListProvider.notifier).closeDetail();
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  detail.playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (detail.playlist.author.isNotEmpty ||
                    detail.playlist.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    [detail.playlist.author, detail.playlist.description]
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .92),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({required this.playlist});

  final OnlinePlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: Icon(Icons.queue_music, size: 44)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CoverImage(
        uri: playlist.coverUri,
        fallback: fallback,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _PlaylistTrackArtwork extends StatelessWidget {
  const _PlaylistTrackArtwork({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 38,
      height: 38,
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
        fallback: fallback,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
      ),
    );
  }
}
