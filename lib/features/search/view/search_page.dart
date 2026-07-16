import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../domain/music.dart';
import '../../library/view/playlist_picker.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
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
    final hotTerms = ref.watch(kuwoHotSearchProvider);
    return RefreshIndicator(
      color: CoralPalette.mint,
      onRefresh: ref.read(searchProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Text(
            '发现',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索歌曲 / 歌手 / 专辑 / 歌单',
              prefixIcon: const Icon(Icons.search_rounded),
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
          const SizedBox(height: 12),
          _SourcePills(state: state),
          if (state.error != null) ...[
            const SizedBox(height: 14),
            _SearchError(
              message: state.error!.message,
              onRetry: ref.read(searchProvider.notifier).refresh,
            ),
          ],
          const SizedBox(height: 22),
          if (state.tracks.isEmpty && state.query.isEmpty)
            _DiscoverySearch(
              terms: hotTerms,
              onSelected: (term) {
                _queryController.text = term;
                _submit(term);
                setState(() {});
              },
              onRetry: () => ref.invalidate(kuwoHotSearchProvider),
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

class _SourcePills extends ConsumerWidget {
  const _SourcePills({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: const [
            OnlineSource.kuwo,
            OnlineSource.netease,
            OnlineSource.migu
          ].length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            const sources = [
              OnlineSource.kuwo,
              OnlineSource.netease,
              OnlineSource.migu
            ];
            final source = sources[index];
            final selected = source == state.source;
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
              onSelected: state.isLoading
                  ? null
                  : (_) =>
                      ref.read(searchProvider.notifier).selectSource(source),
            );
          },
        ),
      );
}

class _DiscoverySearch extends StatelessWidget {
  const _DiscoverySearch({
    required this.terms,
    required this.onSelected,
    required this.onRetry,
  });

  final AsyncValue<List<String>> terms;
  final ValueChanged<String> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('热门搜索',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          terms.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Center(
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('热搜词加载失败，点击重试'),
              ),
            ),
            data: (items) => items.isEmpty
                ? const _EmptySearchSection(message: '暂无热搜词')
                : Column(
                    children: [
                      for (var index = 0; index < items.take(8).length; index++)
                        _HotTermRow(
                          rank: index + 1,
                          term: items[index],
                          onTap: () => onSelected(items[index]),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 26),
          Text('推荐歌手',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final artist = _artists[index];
                return SizedBox(
                  width: 76,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onSelected(artist.name),
                    child: Column(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: artist.colors),
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 7),
                        Text(artist.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '点击歌手卡片会直接发起真实歌曲搜索',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
}

class _HotTermRow extends StatelessWidget {
  const _HotTermRow(
      {required this.rank, required this.term, required this.onTap});

  final int rank;
  final String term;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .67),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: rank <= 3
                          ? const Color(0xffff776c)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                    child: Text(term,
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                Icon(Icons.north_east_rounded,
                    size: 17,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
}

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
          '“${state.query}” 的结果',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < state.tracks.length; index++)
          _SearchTrackTile(
            track: state.tracks[index],
            onTap: () => onPlay(state, index),
          ),
      ],
    );
  }
}

class _SearchTrackTile extends ConsumerWidget {
  const _SearchTrackTile({required this.track, required this.onTap});

  final Track track;
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

class _SearchArtwork extends StatelessWidget {
  const _SearchArtwork({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        gradient:
            LinearGradient(colors: [CoralPalette.sky, CoralPalette.lilac]),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    );
    if (uri == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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

class _ArtistSuggestion {
  const _ArtistSuggestion(this.name, this.colors);

  final String name;
  final List<Color> colors;
}

const _artists = [
  _ArtistSuggestion('周杰伦', [CoralPalette.periwinkle, CoralPalette.player]),
  _ArtistSuggestion('Taylor Swift', [CoralPalette.pink, CoralPalette.lilac]),
  _ArtistSuggestion('陈奕迅', [CoralPalette.peach, CoralPalette.mint]),
  _ArtistSuggestion('G.E.M.', [CoralPalette.sky, CoralPalette.mint]),
];
