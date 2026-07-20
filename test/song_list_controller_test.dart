import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/song_list/data/kuwo_playlist_service.dart';
import 'package:coral_music_mobile/features/song_list/state/song_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appends unique playlist pages and stops at the end', () async {
    final service = _FakePlaylistService();
    final controller = SongListController({OnlineSource.kuwo: service});
    addTearDown(controller.dispose);

    await controller.loadInitial();
    await controller.loadMore();
    await controller.loadMore();

    expect(service.requestedPages, [1, 2]);
    expect(controller.state.page, 2);
    expect(controller.state.hasNext, isFalse);
    expect(
      controller.state.playlists.map((item) => item.id),
      ['1', '2', '3'],
    );
  });
}

final class _FakePlaylistService implements PlaylistCatalogService {
  final requestedPages = <int>[];

  @override
  Future<PageResult<OnlinePlaylist>> getPopularPlaylists(
    int page, {
    String? tagId,
    String sortId = 'hot',
  }) async {
    requestedPages.add(page);
    return PageResult(
      items: page == 1
          ? const [_playlist1, _playlist2]
          : const [_playlist2, _playlist3],
      page: page,
      pageSize: 2,
      total: 3,
    );
  }

  @override
  Future<List<PlaylistTag>> getTags() async => const [];

  @override
  Future<PlaylistDetail> getPlaylistDetail(OnlinePlaylist playlist) async =>
      PlaylistDetail(playlist: playlist, tracks: const []);

  @override
  Future<PageResult<OnlinePlaylist>> searchPlaylists(
    String query,
    int page,
  ) =>
      getPopularPlaylists(page);
}

const _playlist1 = OnlinePlaylist(
  id: '1',
  source: OnlineSource.kuwo,
  name: '歌单 1',
);
const _playlist2 = OnlinePlaylist(
  id: '2',
  source: OnlineSource.kuwo,
  name: '歌单 2',
);
const _playlist3 = OnlinePlaylist(
  id: '3',
  source: OnlineSource.kuwo,
  name: '歌单 3',
);
