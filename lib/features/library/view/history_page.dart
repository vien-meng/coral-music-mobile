import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/cover_image.dart';
import '../../../domain/music.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
import '../data/library_store.dart';
import '../state/library_controller.dart';

final playbackHistoryProvider = FutureProvider<List<PlayHistoryEntry>>(
  (ref) => ref.watch(libraryStoreProvider).listHistory(),
);

final libraryTracksProvider = FutureProvider<List<Track>>(
  (ref) => ref.watch(libraryStoreProvider).listLibraryTracks(),
);

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(playbackHistoryProvider);
    return DefaultTabController(
      length: 5,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('音乐分类',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
          ),
        ),
        const SizedBox(height: 8),
        const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: '播放历史'),
            Tab(text: '艺术家'),
            Tab(text: '专辑'),
            Tab(text: '类型'),
            Tab(text: '年份'),
          ],
        ),
        Expanded(
          child: TabBarView(children: [
            _HistoryList(history: history),
            const _CategoryList(
              label: '艺术家',
              groupBy: _artist,
            ),
            const _CategoryList(
              label: '专辑',
              groupBy: _album,
              canFavoriteAlbum: true,
            ),
            const _CategoryList(
              label: '类型',
              groupBy: _genre,
            ),
            const _CategoryList(
              label: '年份',
              groupBy: _year,
            ),
          ]),
        ),
      ]),
    );
  }
}

String _artist(Track track) =>
    track.artist.trim().isEmpty ? '未知歌手' : track.artist.trim();

String _album(Track track) =>
    track.album?.trim().isNotEmpty == true ? track.album!.trim() : '未知专辑';

String _genre(Track track) => _tag(track, 'genre') ?? '未知类型';

String _year(Track track) => _tag(track, 'year') ?? '未知年份';

String? _tag(Track track, String key) {
  final value = track.extra[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

Map<String, List<Track>> groupTracksBy(
  Iterable<Track> tracks,
  String Function(Track) groupBy,
) {
  final groups = <String, List<Track>>{};
  for (final track in tracks) {
    (groups[groupBy(track)] ??= []).add(track);
  }
  return groups;
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.history});

  final AsyncValue<List<PlayHistoryEntry>> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) => history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(playbackHistoryProvider),
            child: const Text('历史加载失败，点击重试'),
          ),
        ),
        data: (entries) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
            child: Row(children: [
              Text('${entries.length} 首最近播放',
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              TextButton(
                onPressed: entries.isEmpty
                    ? null
                    : () async {
                        await ref.read(libraryStoreProvider).clearHistory();
                        ref.invalidate(playbackHistoryProvider);
                      },
                child: const Text('清空'),
              ),
            ]),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('还没有播放历史。'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _TrackRow(
                      track: entries[index].track,
                      subtitle:
                          '播放 ${entries[index].playCount} 次 · 上次 ${_duration(entries[index].lastPosition)}',
                      onTap: () async {
                        final tracks =
                            entries.map((item) => item.track).toList();
                        ref.read(playbackQueueProvider.notifier).replaceQueue(
                              tracks,
                              startIndex: index,
                              contextId: 'history',
                            );
                        await ref.read(playerProvider.notifier).playTrack(
                              entries[index].track,
                              initialPosition: entries[index].lastPosition,
                            );
                      },
                    ),
                  ),
          ),
        ]),
      );
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({
    required this.label,
    required this.groupBy,
    this.canFavoriteAlbum = false,
  });

  final String label;
  final String Function(Track) groupBy;
  final bool canFavoriteAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(libraryTracksProvider);
    return tracks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(libraryTracksProvider),
          child: const Text('分类加载失败，点击重试'),
        ),
      ),
      data: (items) {
        final groups = groupTracksBy(items, groupBy);
        final names = groups.keys.toList()..sort();
        if (names.isEmpty) return Center(child: Text('还没有可分类的$label。'));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: names.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final name = names[index];
            final group = groups[name]!;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showGroup(context, name, group),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(children: [
                  _Artwork(track: group.first),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(name,
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${group.length} 首',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_outlined),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  void _showGroup(BuildContext context, String name, List<Track> tracks) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _GroupSheet(
        name: name,
        tracks: tracks,
        canFavoriteAlbum: canFavoriteAlbum,
      ),
    );
  }
}

class _GroupSheet extends ConsumerWidget {
  const _GroupSheet({
    required this.name,
    required this.tracks,
    this.canFavoriteAlbum = false,
  });

  final String name;
  final List<Track> tracks;
  final bool canFavoriteAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(children: [
            ListTile(
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${tracks.length} 首歌曲'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (canFavoriteAlbum)
                  IconButton(
                    tooltip: '收藏或取消收藏专辑',
                    icon: const Icon(Icons.bookmark_add_outlined),
                    onPressed: () async {
                      final favorite = await ref
                          .read(libraryProvider.notifier)
                          .toggleFavoriteAlbum(name, tracks);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(favorite ? '已收藏专辑' : '已取消收藏专辑'),
                        ));
                      }
                    },
                  ),
                IconButton(
                  tooltip: '播放全部',
                  icon: const Icon(Icons.play_arrow_outlined),
                  onPressed: () async {
                    final playable = await ref
                        .read(libraryStoreProvider)
                        .filterIgnored(tracks);
                    if (playable.isEmpty) return;
                    ref.read(playbackQueueProvider.notifier).replaceQueue(
                          playable,
                          contextId: 'category:$name',
                        );
                    await ref
                        .read(playerProvider.notifier)
                        .playTrack(playable.first);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: tracks.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) => _TrackRow(
                  track: tracks[index],
                  onTap: () async {
                    ref.read(playbackQueueProvider.notifier).replaceQueue(
                          tracks,
                          startIndex: index,
                          contextId: 'category:$name',
                        );
                    await ref
                        .read(playerProvider.notifier)
                        .playTrack(tracks[index]);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ),
          ]),
        ),
      );
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track, required this.onTap, this.subtitle});

  final Track track;
  final String? subtitle;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(children: [
            _Artwork(track: track),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      subtitle ?? _artist(track),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
            ),
          ]),
        ),
      );
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 42,
          height: 42,
          child: CoverImage(
            uri: track.coverUri,
            fallback: ColoredBox(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.music_note_outlined,
                  color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      );
}

String _duration(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
