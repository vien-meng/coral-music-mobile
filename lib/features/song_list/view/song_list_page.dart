import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../domain/music.dart';
import '../../library/view/favorite_track_button.dart';
import '../../library/view/playlist_picker.dart';
import '../../library/data/library_store.dart';
import '../../download/state/download_controller.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Text('歌单广场', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              PopupMenuButton<OnlineSource>(
                enabled: !state.isLoading,
                tooltip: '切换歌单来源',
                onSelected: ref.read(songListProvider.notifier).selectSource,
                itemBuilder: (context) => [
                  for (final source in const [
                    OnlineSource.kuwo,
                    OnlineSource.qq,
                  ])
                    CheckedPopupMenuItem(
                      value: source,
                      checked: source == state.source,
                      child: Text(source.label),
                    ),
                ],
                icon: const Icon(Icons.library_music_outlined),
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
            enabled: state.source != OnlineSource.qq,
            textInputAction: TextInputAction.search,
            onSubmitted: state.source == OnlineSource.qq
                ? null
                : ref.read(songListProvider.notifier).submitSearch,
            decoration: InputDecoration(
              hintText: state.source == OnlineSource.qq
                  ? 'QQ 歌单关键词搜索暂未接入'
                  : '搜索歌单（清空并搜索可返回广场）',
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
                onPressed: ref.read(songListProvider.notifier).refresh,
                child: const Text('重试'),
              ),
            ],
          ),
        Expanded(
          child: state.isLoading && state.playlists.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: ref.read(songListProvider.notifier).refresh,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 156,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 14,
                      childAspectRatio: .78,
                    ),
                    itemCount: state.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = state.playlists[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: state.isLoading
                            ? null
                            : () => ref
                                .read(songListProvider.notifier)
                                .open(playlist),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _PlaylistCover(playlist: playlist)),
                            const SizedBox(height: 8),
                            Text(
                              playlist.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              playlist.playCount.isEmpty
                                  ? playlist.author
                                  : '${playlist.playCount} 播放',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        if (state.playlists.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '上一页',
                  onPressed: state.page > 1 && !state.isLoading
                      ? ref.read(songListProvider.notifier).previousPage
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('第 ${state.page} 页'),
                IconButton(
                  tooltip: '下一页',
                  onPressed: state.hasNext && !state.isLoading
                      ? ref.read(songListProvider.notifier).nextPage
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回歌单广场',
                  onPressed: ref.read(songListProvider.notifier).closeDetail,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    detail.playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FavoriteOnlinePlaylistButton(detail: detail),
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
                                content: Text(
                                  result.skipped == 0
                                      ? '已加入 ${result.added} 首下载任务'
                                      : '已加入 ${result.added} 首，跳过 ${result.skipped} 首重复或不支持歌曲',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.download_for_offline_outlined),
                ),
                FilledButton.tonalIcon(
                  onPressed: detail.tracks.isEmpty
                      ? null
                      : () async {
                          final tracks = await ref
                              .read(libraryStoreProvider)
                              .filterIgnored(detail.tracks);
                          if (tracks.isEmpty) return;
                          ref.read(playbackQueueProvider.notifier).replaceQueue(
                                tracks,
                                contextId:
                                    'songlist:${detail.playlist.source.id}:${detail.playlist.id}',
                              );
                          await ref
                              .read(playerProvider.notifier)
                              .playTrack(tracks.first);
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('播放全部'),
                ),
              ],
            ),
          ),
          if (detail.playlist.author.isNotEmpty ||
              detail.playlist.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                [detail.playlist.author, detail.playlist.description]
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                        _PlaylistTrackArtwork(uri: track.coverUri),
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
                      IconButton(
                        tooltip: '下载歌曲',
                        onPressed: () =>
                            ref.read(downloadProvider.notifier).enqueue(track),
                        icon: const Icon(Icons.download_outlined),
                      ),
                      IconButton(
                        tooltip: '添加到我的列表',
                        onPressed: () =>
                            addTrackToPlaylist(context, ref, track),
                        icon: const Icon(Icons.playlist_add),
                      ),
                    ],
                  ),
                  onTap: () async {
                    ref.read(playbackQueueProvider.notifier).replaceQueue(
                          detail.tracks,
                          startIndex: index,
                          contextId:
                              'songlist:${detail.playlist.source.id}:${detail.playlist.id}',
                        );
                    await ref.read(playerProvider.notifier).playTrack(track);
                  },
                );
              },
            ),
          ),
        ],
      );
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
    if (playlist.coverUri == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        playlist.coverUri.toString(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
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
    if (uri == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        uri.toString(),
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
