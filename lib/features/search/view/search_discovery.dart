import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/cover_image.dart';

class SearchDiscovery extends StatelessWidget {
  const SearchDiscovery({
    required this.terms,
    required this.history,
    required this.onSelected,
    required this.onClearHistory,
    required this.onRetry,
    super.key,
  });

  final AsyncValue<List<String>> terms;
  final List<String> history;
  final ValueChanged<String> onSelected;
  final VoidCallback onClearHistory;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (history.isNotEmpty) ...[
            Row(children: [
              Text(
                '最近搜索',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                tooltip: '清空搜索历史',
                icon: const Icon(Icons.delete_outline),
                onPressed: onClearHistory,
              ),
            ]),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in history)
                  ActionChip(
                    label: Text(term),
                    onPressed: () => onSelected(term),
                  ),
              ],
            ),
            const SizedBox(height: 26),
          ],
          Text(
            '热门搜索',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
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
                ? const _EmptySection(message: '暂无热搜词')
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
          Text(
            '推荐歌手',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final artist = _artists[index];
                final fallback = DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: artist.colors),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white),
                );
                return SizedBox(
                  width: 76,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onSelected(artist.name),
                    child: Column(
                      children: [
                        Semantics(
                          image: true,
                          label: '${artist.name}头像',
                          child: SizedBox.square(
                            dimension: 66,
                            child: ClipOval(
                              child: CoverImage(
                                uri: Uri.parse(artist.avatar),
                                fallback: fallback,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
}

class _HotTermRow extends StatelessWidget {
  const _HotTermRow({
    required this.rank,
    required this.term,
    required this.onTap,
  });

  final int rank;
  final String term;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
                  child: Text(
                    term,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.north_east_rounded,
                  size: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Center(child: Text(message)),
      );
}

class _ArtistSuggestion {
  const _ArtistSuggestion(this.name, this.avatar, this.colors);

  final String name;
  final String avatar;
  final List<Color> colors;
}

const _artists = [
  _ArtistSuggestion(
    '周杰伦',
    'https://y.gtimg.cn/music/photo_new/T001R300x300M0000025NhlN2yWrP4.jpg',
    [CoralPalette.periwinkle, CoralPalette.player],
  ),
  _ArtistSuggestion(
    'Taylor Swift',
    'https://y.gtimg.cn/music/photo_new/T001R300x300M000000qrPik2w6lDr.jpg',
    [CoralPalette.pink, CoralPalette.lilac],
  ),
  _ArtistSuggestion(
    '陈奕迅',
    'https://y.gtimg.cn/music/photo_new/T001R300x300M000003Nz2So3XXYek.jpg',
    [CoralPalette.peach, CoralPalette.mint],
  ),
  _ArtistSuggestion(
    'G.E.M.',
    'https://y.gtimg.cn/music/photo_new/T001R300x300M000001fNHEf1SFEFN.jpg',
    [CoralPalette.sky, CoralPalette.mint],
  ),
];
