import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/cover_image.dart';
import '../../../app/online_source_menu.dart';
import '../../../app/app_theme.dart';
import '../../../domain/music.dart';
import '../../download/view/download_track_button.dart';
import '../../library/view/favorite_track_button.dart';
import '../../library/view/playlist_picker.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';
import '../../player/state/user_api_debug_controller.dart';
import '../../song_list/state/song_list_controller.dart';
import '../state/search_controller.dart';
import 'search_album_detail_page.dart';
import 'search_discovery.dart';

typedef _PlaylistSearch = ({OnlineSource source, String query, int page});

final _playlistSearchProvider = FutureProvider.autoDispose
    .family<PageResult<OnlinePlaylist>, _PlaylistSearch>(
  (ref, request) {
    final service = ref.watch(playlistCatalogServicesProvider)[request.source];
    return service?.searchPlaylists(request.query, request.page) ??
        Future.value(PageResult(
            items: const [], page: request.page, pageSize: 30, total: 0));
  },
);

enum _SearchResultTab { tracks, playlists, albums }

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  final _queryController = TextEditingController();
  late final TabController _tabController;
  var _tab = _SearchResultTab.tracks;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: _SearchResultTab.values.length, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _tab = _SearchResultTab.values[_tabController.index]);
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final hotTerms = ref.watch(hotSearchProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Column(
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
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: CoralPalette.mint,
            onRefresh: ref.read(searchProvider.notifier).refresh,
            child: state.tracks.isEmpty && state.query.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: [
                      SearchDiscovery(
                        terms: hotTerms,
                        history: state.history,
                        onSelected: (term) {
                          _queryController.text = term;
                          _submit(term);
                          setState(() {});
                        },
                        onClearHistory:
                            ref.read(searchProvider.notifier).clearHistory,
                        onRetry: () => ref.invalidate(hotSearchProvider),
                      ),
                    ],
                  )
                : _SearchResults(
                    state: state,
                    tab: _tab,
                    tabController: _tabController,
                    onPlay: _playTrack,
                    onPlayAlbum: _playAlbum,
                  ),
          ),
        ),
      ],
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

  Future<void> _playAlbum(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    ref.read(playbackQueueProvider.notifier).replaceQueue(
          tracks,
          contextId:
              'search-album:${tracks.first.sourceId}:${tracks.first.album}',
        );
    await ref.read(playerProvider.notifier).playTrack(tracks.first);
  }
}

class _SearchHeader extends ConsumerWidget {
  const _SearchHeader({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const candidates = [
      OnlineSource.kuwo,
      OnlineSource.kugou,
      OnlineSource.qq,
      OnlineSource.netease,
      OnlineSource.migu,
    ];
    final supported = ref.watch(userApiDebugProvider.select((userApi) =>
        userApi.activeSource?.musicUrlSources ?? const <String>{}));
    final sources = supportedOnlineSources(candidates, supported);
    return Row(
      children: [
        Text('搜索',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                )),
        const Spacer(),
        OnlineSourceMenu(
          activeSource: state.source,
          isLoading: state.isLoading,
          isCombined: state.isCombined,
          onSelectCombined: sources.length == candidates.length
              ? ref.read(searchProvider.notifier).selectCombined
              : null,
          sources: sources,
          onSelected: ref.read(searchProvider.notifier).selectSource,
        ),
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.state,
    required this.tab,
    required this.tabController,
    required this.onPlay,
    required this.onPlayAlbum,
  });

  final SearchState state;
  final _SearchResultTab tab;
  final TabController tabController;
  final Future<void> Function(SearchState state, int index) onPlay;
  final Future<void> Function(List<Track> tracks) onPlayAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.tracks.isEmpty && tab != _SearchResultTab.playlists) {
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
        TabBar(
          controller: tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '热门歌曲'),
            Tab(text: '歌单'),
            Tab(text: '专辑'),
          ],
        ),
        Expanded(
          child: switch (tab) {
            _SearchResultTab.tracks => _TrackResults(
                state: state,
                onPlay: onPlay,
              ),
            _SearchResultTab.playlists => _PlaylistResults(state: state),
            _SearchResultTab.albums => _AlbumResults(
                tracks: state.tracks,
                onPlay: onPlayAlbum,
              ),
          },
        ),
      ],
    );
  }
}

class _TrackResults extends StatelessWidget {
  const _TrackResults({required this.state, required this.onPlay});

  final SearchState state;
  final Future<void> Function(SearchState state, int index) onPlay;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          for (var index = 0; index < state.tracks.length; index++)
            _SearchTrackTile(
              track: state.tracks[index],
              showSource: state.isCombined,
              onTap: () => onPlay(state, index),
            ),
          _Pagination(state: state),
        ],
      );
}

class _PlaylistResults extends ConsumerWidget {
  const _PlaylistResults({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isCombined) {
      return const _EmptySearchSection(message: '综合搜索暂不聚合歌单');
    }
    final result = ref.watch(_playlistSearchProvider((
      source: state.source,
      query: state.query,
      page: state.page,
    )));
    return result.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _EmptySearchSection(message: '当前平台暂未返回歌单'),
      data: (page) => page.items.isEmpty
          ? const _EmptySearchSection(message: '暂无匹配歌单')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                for (final playlist in page.items)
                  _SearchPlaylistTile(playlist: playlist),
              ],
            ),
    );
  }
}

class _SearchPlaylistTile extends ConsumerWidget {
  const _SearchPlaylistTile({required this.playlist});

  final OnlinePlaylist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: _SearchArtwork(uri: playlist.coverUri),
        title:
            Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            playlist.author,
            playlist.playCount.isEmpty ? '' : '${playlist.playCount} 播放'
          ].where((value) => value.isNotEmpty).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await ref.read(songListProvider.notifier).open(playlist);
          if (context.mounted) context.push('/song-list/detail');
        },
      );
}

class _AlbumResults extends StatelessWidget {
  const _AlbumResults({required this.tracks, required this.onPlay});

  final List<Track> tracks;
  final Future<void> Function(List<Track> tracks) onPlay;

  @override
  Widget build(BuildContext context) {
    final albums = <String, List<Track>>{};
    for (final track in tracks) {
      final name = track.album?.trim() ?? '';
      if (name.isEmpty) continue;
      albums.putIfAbsent('${track.sourceId}:$name', () => []).add(track);
    }
    if (albums.isEmpty) return const _EmptySearchSection(message: '暂无匹配专辑');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        for (final items in albums.values)
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            leading: _SearchArtwork(uri: items.first.coverUri),
            title: Text(items.first.album!,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${items.first.artist} · ${items.length} 首匹配歌曲'),
            trailing: IconButton(
              tooltip: '播放专辑匹配歌曲',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => onPlay(items),
            ),
            onTap: () => context.push(
              '/album-detail',
              extra: SearchAlbumDetail(
                title: items.first.album!,
                artist: items.first.artist,
                tracks: items,
              ),
            ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CoverImage(
        uri: uri,
        fallback: fallback,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
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
