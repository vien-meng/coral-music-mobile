import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../domain/music.dart';
import '../../download/view/download_track_button.dart';
import '../../library/view/favorite_track_button.dart';
import '../../library/view/playlist_picker.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
import '../state/search_controller.dart';
import 'search_discovery.dart';

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
    final hotTerms = ref.watch(hotSearchProvider);
    return RefreshIndicator(
      color: CoralPalette.mint,
      onRefresh: ref.read(searchProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          _SearchHeader(state: state),
          const SizedBox(height: 16),
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索歌曲 / 歌手 / 专辑 / 歌单',
              prefixIcon: const Icon(Icons.search_outlined),
              suffixIcon: _queryController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _queryController.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 14),
            _SearchError(
              message: state.error!.message,
              onRetry: ref.read(searchProvider.notifier).refresh,
            ),
          ],
          const SizedBox(height: 22),
          if (state.tracks.isEmpty && state.query.isEmpty)
            SearchDiscovery(
              terms: hotTerms,
              history: state.history,
              onSelected: (term) {
                _queryController.text = term;
                _submit(term);
                setState(() {});
              },
              onClearHistory: ref.read(searchProvider.notifier).clearHistory,
              onRetry: () => ref.invalidate(hotSearchProvider),
            )
          else
            _SearchResults(
              state: state,
              onPlay: _playTrack,
            ),
          if (state.tracks.isNotEmpty) _Pagination(state: state),
        ],
      ),
    );
  }

  void _submit(String query) {
    FocusScope.of(context).unfocus();
    ref.read(searchProvider.notifier).submit(query);
  }

  Future<void> _playTrack(SearchState state, int index) async {
    final track = state.tracks[index];
    ref.read(playbackQueueProvider.notifier).replaceQueue(
          state.tracks,
          startIndex: index,
          contextId: 'search:${state.source.id}:${state.query}:${state.page}',
        );
    await ref.read(playerProvider.notifier).playTrack(track);
  }
}

class _SearchHeader extends ConsumerWidget {
  const _SearchHeader({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
        children: [
          Text('搜索',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                  )),
          const Spacer(),
          PopupMenuButton<_SearchMenuAction>(
            enabled: !state.isLoading,
            tooltip: '切换搜索来源',
            onSelected: (action) {
              switch (action) {
                case _SearchMenuAction.combined:
                  ref.read(searchProvider.notifier).selectCombined();
                case _SearchMenuAction.kuwo:
                  ref
                      .read(searchProvider.notifier)
                      .selectSource(OnlineSource.kuwo);
                case _SearchMenuAction.kugou:
                  ref
                      .read(searchProvider.notifier)
                      .selectSource(OnlineSource.kugou);
                case _SearchMenuAction.qq:
                  ref
                      .read(searchProvider.notifier)
                      .selectSource(OnlineSource.qq);
                case _SearchMenuAction.netease:
                  ref
                      .read(searchProvider.notifier)
                      .selectSource(OnlineSource.netease);
                case _SearchMenuAction.migu:
                  ref
                      .read(searchProvider.notifier)
                      .selectSource(OnlineSource.migu);
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: _SearchMenuAction.combined,
                checked: state.isCombined,
                child: const Text('综合搜索'),
              ),
              const PopupMenuDivider(),
              for (final entry in const [
                (_SearchMenuAction.kuwo, OnlineSource.kuwo),
                (_SearchMenuAction.kugou, OnlineSource.kugou),
                (_SearchMenuAction.qq, OnlineSource.qq),
                (_SearchMenuAction.netease, OnlineSource.netease),
                (_SearchMenuAction.migu, OnlineSource.migu),
              ])
                CheckedPopupMenuItem(
                  value: entry.$1,
                  checked: entry.$2 == state.source && !state.isCombined,
                  child: Text(entry.$2.label),
                ),
            ],
            icon: const Icon(Icons.library_music_outlined),
          ),
        ],
      );
}

enum _SearchMenuAction { combined, kuwo, kugou, qq, netease, migu }

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.state, required this.onPlay});

  final SearchState state;
  final Future<void> Function(SearchState state, int index) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.tracks.isEmpty) {
      return _EmptySearchSection(
        message: state.query.isEmpty ? '输入歌曲或歌手开始搜索' : '暂无搜索结果',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '“${state.query}” 的${state.isCombined ? '综合' : state.source.label}结果',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < state.tracks.length; index++)
          _SearchTrackTile(
            track: state.tracks[index],
            showSource: state.isCombined,
            onTap: () => onPlay(state, index),
          ),
      ],
    );
  }
}

class _SearchTrackTile extends ConsumerWidget {
  const _SearchTrackTile({
    required this.track,
    required this.showSource,
    required this.onTap,
  });

  final Track track;
  final bool showSource;
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
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  _SearchArtwork(uri: track.coverUri),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (showSource) _sourceLabel(track),
                            track.artist,
                            if (track.album?.isNotEmpty == true) track.album!
                          ].where((value) => value.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
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
}

String _sourceLabel(Track track) =>
    OnlineSource.values
        .where((source) => source.id == track.sourceId)
        .firstOrNull
        ?.label ??
    track.sourceId;

class _SearchArtwork extends StatelessWidget {
  const _SearchArtwork({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 48,
      height: 48,
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
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        color:
            Theme.of(context).colorScheme.errorContainer.withValues(alpha: .58),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
              TextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
}

class _EmptySearchSection extends StatelessWidget {
  const _EmptySearchSection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Center(child: Text(message)),
      );
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一页',
              onPressed: state.hasPrevious && !state.isLoading
                  ? ref.read(searchProvider.notifier).previousPage
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text('第 ${state.page} 页 · 共 ${state.total} 首'),
            IconButton(
              tooltip: '下一页',
              onPressed: state.hasNext && !state.isLoading
                  ? ref.read(searchProvider.notifier).nextPage
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );
}
