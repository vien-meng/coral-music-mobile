import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../state/library_controller.dart';

Future<void> addTrackToPlaylist(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final controller = ref.read(libraryProvider.notifier);
  await controller.load();
  if (!context.mounted) return;
  final playlists = ref.read(libraryProvider).playlists;
  if (playlists.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先在“我的列表”中新建列表。')),
    );
    return;
  }
  final playlist = await showModalBottomSheet<UserPlaylist>(
    context: context,
    showDragHandle: true,
    builder: (context) => ListView(
      shrinkWrap: true,
      children: [
        const ListTile(title: Text('添加到我的列表')),
        for (final item in playlists)
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: Text(item.name),
            onTap: () => Navigator.pop(context, item),
          ),
      ],
    ),
  );
  if (playlist == null || !context.mounted) return;
  final added = await controller.addTrack(playlist, track);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(added ? '已加入“${playlist.name}”' : '歌曲已在此列表中')),
  );
}
