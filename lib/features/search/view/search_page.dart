import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/state/playback_queue_controller.dart';
import '../state/search_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submit,
                  decoration: InputDecoration(
                    hintText: '搜索歌曲',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _queryController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _queryController.clear();
                              setState(() {});
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                tooltip: '搜索',
                onPressed: state.isLoading
                    ? null
                    : () => _submit(_queryController.text),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(Icons.music_note, size: 18),
              label: Text('酷我音乐'),
            ),
          ),
        ),
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!.message),
            actions: [
              TextButton(
                onPressed: ref.read(searchProvider.notifier).refresh,
                child: const Text('重试'),
              ),
            ],
          ),
        Expanded(child: _SearchResults(state: state)),
        if (state.tracks.isNotEmpty) _Pagination(state: state),
      ],
    );
  }

  void _submit(String query) {
    FocusScope.of(context).unfocus();
    ref.read(searchProvider.notifier).submit(query);
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.tracks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.tracks.isEmpty) {
      return Center(
          child: Text(state.query.isEmpty ? '输入歌曲或歌手开始搜索' : '暂无搜索结果'));
    }
    return RefreshIndicator(
      onRefresh: ref.read(searchProvider.notifier).refresh,
      child: ListView.separated(
        key: const Key('search-tracks'),
        itemCount: state.tracks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final track = state.tracks[index];
          return ListTile(
            leading: const SizedBox.square(
              dimension: 48,
              child: Icon(Icons.music_note),
            ),
            title:
                Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              track.artist.isEmpty ? '未知歌手' : track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(_duration(track.duration)),
            onTap: () => ref.read(playbackQueueProvider.notifier).replaceQueue(
                  state.tracks,
                  startIndex: index,
                  contextId:
                      'search:${state.source.id}:${state.query}:${state.page}',
                ),
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

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一页',
              onPressed: state.hasPrevious && !state.isLoading
                  ? ref.read(searchProvider.notifier).previousPage
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('第 ${state.page} 页 · 共 ${state.total} 首'),
            IconButton(
              tooltip: '下一页',
              onPressed: state.hasNext && !state.isLoading
                  ? ref.read(searchProvider.notifier).nextPage
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      );
}
