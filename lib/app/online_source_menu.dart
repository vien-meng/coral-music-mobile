import 'package:flutter/material.dart';

import '../domain/music.dart';

List<OnlineSource> supportedOnlineSources(
  Iterable<OnlineSource> candidates,
  Set<String> supportedSourceIds,
) =>
    candidates
        .where((source) => supportedSourceIds.contains(source.id))
        .toList(growable: false);

class OnlineSourceMenu extends StatelessWidget {
  const OnlineSourceMenu({
    required this.activeSource,
    required this.sources,
    required this.onSelected,
    this.isLoading = false,
    this.isCombined = false,
    this.onSelectCombined,
    super.key,
  });

  final OnlineSource activeSource;
  final List<OnlineSource> sources;
  final ValueChanged<OnlineSource> onSelected;
  final bool isLoading;
  final bool isCombined;
  final VoidCallback? onSelectCombined;

  @override
  Widget build(BuildContext context) => MenuAnchor(
        style: onlineSourceMenuStyle(context),
        menuChildren: [
          const OnlineSourceMenuHeading(title: '音乐平台'),
          if (sources.isEmpty && onSelectCombined == null)
            const SizedBox(
              width: 220,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text('当前音源未声明可播放的平台'),
              ),
            ),
          if (onSelectCombined case final selectCombined?)
            _MenuItem(
              icon: Icons.grid_view_rounded,
              label: '综合搜索',
              selected: isCombined,
              onPressed: isCombined ? null : selectCombined,
            ),
          for (final source in sources)
            _MenuItem(
              icon: onlineSourceIcon(source),
              label: source.label,
              selected: source == activeSource && !isCombined,
              onPressed: source == activeSource && !isCombined
                  ? null
                  : () => onSelected(source),
            ),
        ],
        builder: (context, controller, _) => IconButton(
          tooltip: '切换音乐来源',
          onPressed: isLoading
              ? null
              : () =>
                  controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(
            Icons.library_music_outlined,
            color: controller.isOpen
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => MenuItemButton(
        leadingIcon: Icon(
          icon,
          size: 20,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        trailingIcon: selected
            ? Icon(
                Icons.check_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              )
            : const SizedBox(width: 18),
        onPressed: onPressed,
        child: SizedBox(width: 126, child: Text(label)),
      );
}

class OnlineSourceMenuHeading extends StatelessWidget {
  const OnlineSourceMenuHeading({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      );
}

MenuStyle onlineSourceMenuStyle(BuildContext context) => MenuStyle(
      backgroundColor:
          WidgetStatePropertyAll(Theme.of(context).colorScheme.surface),
      elevation: const WidgetStatePropertyAll(6),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
    );

IconData onlineSourceIcon(OnlineSource source) => switch (source) {
      OnlineSource.kuwo => Icons.graphic_eq_rounded,
      OnlineSource.qq => Icons.chat_bubble_outline_rounded,
      OnlineSource.migu => Icons.headphones_rounded,
      OnlineSource.netease => Icons.album_outlined,
      OnlineSource.kugou => Icons.music_note_rounded,
    };
