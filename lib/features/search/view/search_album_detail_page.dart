import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/cover_image.dart';
import '../../../domain/music.dart';
import '../../download/state/download_controller.dart';
import '../../download/view/download_track_button.dart';
import '../../library/data/library_store.dart';
import '../../library/view/favorite_track_button.dart';
import '../../library/view/playlist_picker.dart';
import '../../player/state/playback_queue_controller.dart';
import '../../player/state/player_controller.dart';

final class SearchAlbumDetail {
  const SearchAlbumDetail({
    required this.title,
    required this.artist,
    required this.tracks,
  });

  final String title;
  final String artist;
  final List<Track> tracks;
}

class SearchAlbumDetailPage extends ConsumerWidget {
  const SearchAlbumDetailPage({required this.detail, super.key});

  final SearchAlbumDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Column(
          children: [
            _AlbumDetailBanner(detail: detail),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed:
                        detail.tracks.isEmpty ? null : () => _playAll(ref),
                    icon: const Icon(Icons.play_arrow),
                    label: Text('播放全部 (${detail.tracks.length})'),
                  ),
                  FavoriteAlbumButton(
                    name: detail.title,
                    tracks: detail.tracks,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '下载全部',
                    onPressed: detail.tracks.isEmpty
                        ? null
                        : () => _downloadAll(context, ref),
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
                          _Artwork(uri: track.coverUri, size: 38),
                        ],
                      ),
                    ),
                    title: Text(track.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(track.artist,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FavoriteTrackButton(track: track, compact: true),
                        DownloadTrackButton(track: track, compact: true),
                        IconButton(
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(40),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          tooltip: '添加到我的列表',
                          onPressed: () =>
                              addTrackToPlaylist(context, ref, track),
                          icon: const Icon(Icons.playlist_add),
                        ),
                      ],
                    ),
                    onTap: () => _play(ref, index),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Future<void> _playAll(WidgetRef ref) async {
    final tracks = await ref.read(libraryStoreProvider).filterIgnored(
          detail.tracks,
        );
    if (tracks.isEmpty) return;
    ref.read(playbackQueueProvider.notifier).replaceQueue(
          tracks,
          contextId: 'search-album:${tracks.first.sourceId}:${detail.title}',
        );
    await ref.read(playerProvider.notifier).playTrack(tracks.first);
  }

  Future<void> _downloadAll(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(downloadProvider.notifier).enqueueAll(detail.tracks);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.skipped == 0
            ? '已加入 ${result.added} 首下载任务'
            : '已加入 ${result.added} 首，跳过 ${result.skipped} 首重复或不支持歌曲'),
      ),
    );
  }

  Future<void> _play(WidgetRef ref, int index) async {
    final track = detail.tracks[index];
    ref.read(playbackQueueProvider.notifier).replaceQueue(
          detail.tracks,
          startIndex: index,
          contextId: 'search-album:${track.sourceId}:${detail.title}',
        );
    await ref.read(playerProvider.notifier).playTrack(track);
  }
}

class _AlbumDetailBanner extends StatelessWidget {
  const _AlbumDetailBanner({required this.detail});

  final SearchAlbumDetail detail;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 224,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverImage(
              uri: detail.tracks.isEmpty ? null : detail.tracks.first.coverUri,
              fit: BoxFit.cover,
              fallback: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.album_outlined, size: 56),
              ),
            ),
            const ColoredBox(color: Color(0x66000000)),
            Positioned(
              top: 6,
              left: 6,
              child: IconButton(
                tooltip: '返回',
                color: Colors.white,
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/search');
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
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
                    detail.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    detail.artist.isEmpty ? '未知歌手' : detail.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .92),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.uri, required this.size});

  final Uri? uri;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CoverImage(
          uri: uri,
          width: size,
          height: size,
          fallback: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SizedBox.square(
              dimension: size,
              child: const Icon(Icons.album_outlined),
            ),
          ),
        ),
      );
}
