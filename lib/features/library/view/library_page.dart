import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
import '../state/library_controller.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({this.favoritesOnly = false, super.key});

  final bool favoritesOnly;

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => widget.favoritesOnly
          ? ref.read(libraryProvider.notifier).openFavorites()
          : ref.read(libraryProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    if (state.selectedPlaylist case final playlist?) {
      return _PlaylistTracks(
        playlist: playlist,
        tracks: state.tracks,
        showBack: !widget.favoritesOnly,
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading ? null : () => _editPlaylist(context),
        icon: const Icon(Icons.add),
        label: const Text('新建列表'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text('我的列表', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: '刷新',
                  onPressed: state.isLoading
                      ? null
                      : ref.read(libraryProvider.notifier).load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (state.error != null)
            MaterialBanner(
              content: Text(state.error!.message),
              actions: [
                TextButton(
                  onPressed: ref.read(libraryProvider.notifier).load,
                  child: const Text('重试'),
                ),
              ],
            ),
          Expanded(
            child: state.isLoading && state.playlists.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.playlists.isEmpty
                    ? const _EmptyLibrary()
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                        itemCount: state.playlists.length,
                        onReorder: state.isLoading
                            ? (_, __) {}
                            : ref.read(libraryProvider.notifier).reorder,
                        itemBuilder: (context, index) {
                          final playlist = state.playlists[index];
                          return Card(
                            key: ValueKey(playlist.id),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              title: Text(playlist.name),
                              subtitle: const Text('点击查看歌曲'),
                              onTap: state.isLoading
                                  ? null
                                  : () => ref
                                      .read(libraryProvider.notifier)
                                      .open(playlist),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: '重命名',
                                    onPressed: state.isLoading
                                        ? null
                                        : () => _editPlaylist(
                                              context,
                                              playlist: playlist,
                                            ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '删除',
                                    onPressed: state.isLoading
                                        ? null
                                        : () =>
                                            _deletePlaylist(context, playlist),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPlaylist(
    BuildContext context, {
    UserPlaylist? playlist,
  }) async {
    final controller = TextEditingController(text: playlist?.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(playlist == null ? '新建列表' : '重命名列表'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(hintText: '列表名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    final normalized = name?.trim();
    if (normalized == null || normalized.isEmpty) return;
    final library = ref.read(libraryProvider.notifier);
    if (playlist == null) {
      await library.create(normalized);
    } else {
      await library.rename(playlist, normalized);
    }
  }

  Future<void> _deletePlaylist(
    BuildContext context,
    UserPlaylist playlist,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除列表？'),
        content: Text('“${playlist.name}”中的歌曲也会一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await ref.read(libraryProvider.notifier).delete(playlist.id);
    }
  }
}

class _PlaylistTracks extends ConsumerStatefulWidget {
  const _PlaylistTracks({
    required this.playlist,
    required this.tracks,
    required this.showBack,
  });

  final UserPlaylist playlist;
  final List<Track> tracks;
  final bool showBack;

  @override
  ConsumerState<_PlaylistTracks> createState() => _PlaylistTracksState();
}

class _PlaylistTracksState extends ConsumerState<_PlaylistTracks> {
  String _query = '';
  TrackSourceKind? _sourceKind;
  final _selectedTrackIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final tracks = widget.tracks;
    final visibleTracks = tracks.where(_matchesFilter).toList(growable: false);
    final isLoading = ref.watch(libraryProvider).isLoading;
    final canReorder = !isLoading &&
        _selectedTrackIds.isEmpty &&
        _query.trim().isEmpty &&
        _sourceKind == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              if (widget.showBack)
                IconButton(
                  tooltip: '返回我的列表',
                  onPressed: ref.read(libraryProvider.notifier).close,
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Text(
                  _selectedTrackIds.isEmpty
                      ? playlist.name
                      : '已选择 ${_selectedTrackIds.length} 首',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_selectedTrackIds.isEmpty)
                FilledButton.tonalIcon(
                  onPressed: visibleTracks.isEmpty || isLoading
                      ? null
                      : () async {
                          ref.read(playbackQueueProvider.notifier).replaceQueue(
                                visibleTracks,
                                contextId: 'library:${playlist.id}',
                              );
                          await ref
                              .read(playerProvider.notifier)
                              .playTrack(visibleTracks.first);
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('播放全部'),
                )
              else ...[
                IconButton(
                  tooltip: '取消选择',
                  onPressed: () => setState(_selectedTrackIds.clear),
                  icon: const Icon(Icons.close),
                ),
                IconButton(
                  tooltip: '复制到其他列表',
                  onPressed: isLoading
                      ? null
                      : () => _transferSelected(context, move: false),
                  icon: const Icon(Icons.content_copy_outlined),
                ),
                IconButton(
                  tooltip: '移动到其他列表',
                  onPressed: isLoading
                      ? null
                      : () => _transferSelected(context, move: true),
                  icon: const Icon(Icons.drive_file_move_outline),
                ),
                IconButton(
                  tooltip: '置顶已选歌曲',
                  onPressed: isLoading
                      ? null
                      : () async {
                          await ref
                              .read(libraryProvider.notifier)
                              .pinTracks(_selectedTrackIds);
                          if (mounted) setState(_selectedTrackIds.clear);
                        },
                  icon: const Icon(Icons.vertical_align_top),
                ),
                IconButton(
                  tooltip: '删除已选歌曲',
                  onPressed: isLoading ? null : () => _removeSelected(context),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: '搜索当前列表',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<TrackSourceKind?>(
                value: _sourceKind,
                hint: const Text('来源'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  for (final source in TrackSourceKind.values)
                    DropdownMenuItem(
                      value: source,
                      child: Text(_sourceKindLabel(source)),
                    ),
                ],
                onChanged: (value) => setState(() => _sourceKind = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? const _EmptyLibrary(message: '列表还没有歌曲。')
              : visibleTracks.isEmpty
                  ? const _EmptyLibrary(message: '没有匹配的歌曲。')
                  : canReorder
                      ? ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: tracks.length,
                          onReorder:
                              ref.read(libraryProvider.notifier).reorderTracks,
                          itemBuilder: (context, index) => _trackTile(
                            tracks[index],
                            index,
                            tracks,
                            isLoading,
                            true,
                          ),
                        )
                      : ListView.separated(
                          itemCount: visibleTracks.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) => _trackTile(
                            visibleTracks[index],
                            index,
                            visibleTracks,
                            isLoading,
                            false,
                          ),
                        ),
        ),
      ],
    );
  }

  bool _matchesFilter(Track track) {
    if (_sourceKind != null && track.sourceKind != _sourceKind) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [track.title, track.artist, track.album ?? '', track.sourceId]
        .join('\n')
        .toLowerCase()
        .contains(query);
  }

  void _toggleSelected(String id) => setState(() {
        if (!_selectedTrackIds.add(id)) _selectedTrackIds.remove(id);
      });

  Future<void> _removeSelected(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除已选歌曲？'),
        content: Text('将从当前列表移除 ${_selectedTrackIds.length} 首歌曲。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await ref.read(libraryProvider.notifier).removeTracks(_selectedTrackIds);
    if (mounted) setState(_selectedTrackIds.clear);
  }

  Future<void> _transferSelected(
    BuildContext context, {
    required bool move,
  }) async {
    final controller = ref.read(libraryProvider.notifier);
    await controller.load();
    if (!context.mounted) return;
    final destinations = ref
        .read(libraryProvider)
        .playlists
        .where((playlist) => playlist.id != widget.playlist.id)
        .toList(growable: false);
    if (destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先新建另一个列表。')),
      );
      return;
    }
    final destination = await showModalBottomSheet<UserPlaylist>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(move ? '移动到其他列表' : '复制到其他列表')),
          for (final playlist in destinations)
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(playlist.name),
              onTap: () => Navigator.pop(context, playlist),
            ),
        ],
      ),
    );
    if (destination == null || !context.mounted) return;
    final added = await controller.transferTracks(
      destination.id,
      _selectedTrackIds,
      move: move,
    );
    if (!context.mounted) return;
    setState(_selectedTrackIds.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${move ? '移动' : '复制'}完成，新增 $added 首歌曲。')),
    );
  }

  String _sourceKindLabel(TrackSourceKind source) => switch (source) {
        TrackSourceKind.online => '在线',
        TrackSourceKind.local => '本地',
        TrackSourceKind.download => '下载',
        TrackSourceKind.webdav => 'WebDAV',
      };

  Widget _trackTile(
    Track track,
    int index,
    List<Track> queueTracks,
    bool isLoading,
    bool canReorder,
  ) {
    final selected = _selectedTrackIds.contains(track.id);
    return ListTile(
      key: ValueKey(track.id),
      selected: selected,
      leading: Checkbox(
        value: selected,
        onChanged: isLoading ? null : (_) => _toggleSelected(track.id),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist.isEmpty ? '未知歌手' : track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '从列表移除',
            onPressed: isLoading
                ? null
                : () async {
                    await ref
                        .read(libraryProvider.notifier)
                        .removeTrack(track.id);
                    if (mounted) {
                      setState(() => _selectedTrackIds.remove(track.id));
                    }
                  },
            icon: const Icon(Icons.remove_circle_outline),
          ),
          if (canReorder)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.drag_handle),
              ),
            ),
        ],
      ),
      onTap: isLoading
          ? null
          : _selectedTrackIds.isNotEmpty
              ? () => _toggleSelected(track.id)
              : () async {
                  ref.read(playbackQueueProvider.notifier).replaceQueue(
                        queueTracks,
                        startIndex: index,
                        contextId: 'library:${widget.playlist.id}',
                      );
                  await ref.read(playerProvider.notifier).playTrack(track);
                },
      onLongPress: isLoading ? null : () => _toggleSelected(track.id),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({this.message = '还没有列表，点击右下角新建一个吧。'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(message),
      );
}
