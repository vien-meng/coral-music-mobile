import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../../library/data/library_store.dart';

final ignoredTracksProvider = FutureProvider<List<Track>>(
  (ref) => ref.watch(libraryStoreProvider).listIgnoredTracks(),
);

final ignoredKeywordsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(libraryStoreProvider).listIgnoredKeywords(),
);

class IgnoredTracksPage extends ConsumerStatefulWidget {
  const IgnoredTracksPage({super.key});

  @override
  ConsumerState<IgnoredTracksPage> createState() => _IgnoredTracksPageState();
}

class _IgnoredTracksPageState extends ConsumerState<IgnoredTracksPage> {
  final _keywordController = TextEditingController();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(ignoredTracksProvider);
    final keywords = ref.watch(ignoredKeywordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('不感兴趣'),
        actions: [
          IconButton(
            tooltip: '清空规则',
            onPressed: () async {
              await ref.read(libraryStoreProvider).clearIgnored();
              await ref.read(libraryStoreProvider).clearIgnoredKeywords();
              ref.invalidate(ignoredTracksProvider);
              ref.invalidate(ignoredKeywordsProvider);
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: tracks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('规则读取失败')),
        data: (items) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child:
                  Text('关键词规则', style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _keywordController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: '歌名、歌手或专辑关键词',
                  suffixIcon: IconButton(
                    tooltip: '添加关键词',
                    onPressed: _addKeyword,
                    icon: const Icon(Icons.add),
                  ),
                ),
                onSubmitted: (_) => _addKeyword(),
              ),
            ),
            keywords.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('关键词读取失败'),
              ),
              data: (values) => Wrap(
                spacing: 8,
                children: [
                  for (final keyword in values)
                    InputChip(
                      label: Text(keyword),
                      onDeleted: () async {
                        await ref
                            .read(libraryStoreProvider)
                            .removeIgnoredKeyword(keyword);
                        ref.invalidate(ignoredKeywordsProvider);
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child:
                  Text('单曲规则', style: Theme.of(context).textTheme.titleMedium),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('还没有不感兴趣的歌曲。'),
              )
            else
              for (final track in items)
                ListTile(
                  title: Text(track.title),
                  subtitle: Text(track.artist.isEmpty ? '未知歌手' : track.artist),
                  trailing: IconButton(
                    tooltip: '恢复此曲',
                    onPressed: () async {
                      await ref.read(libraryStoreProvider).toggleIgnored(track);
                      ref.invalidate(ignoredTracksProvider);
                    },
                    icon: const Icon(Icons.undo_outlined),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _addKeyword() async {
    final value = _keywordController.text;
    try {
      await ref.read(libraryStoreProvider).addIgnoredKeyword(value);
      _keywordController.clear();
      ref.invalidate(ignoredKeywordsProvider);
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message.toString())));
      }
    }
  }
}
