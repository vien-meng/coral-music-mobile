import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../state/playback_queue_controller.dart';
import '../state/player_controller.dart';
import 'playback_queue_drawer.dart';
import 'player_controls_panel.dart';
import 'player_lyrics_panel.dart';

enum _DetailPanel { player, lyrics }

class PlayerDetailPage extends ConsumerStatefulWidget {
  const PlayerDetailPage({super.key});

  @override
  ConsumerState<PlayerDetailPage> createState() => _PlayerDetailPageState();
}

class _PlayerDetailPageState extends ConsumerState<PlayerDetailPage> {
  final _pageController = PageController();
  var _panel = _DetailPanel.player;
  var _pullDownDistance = 0.0;
  var _isClosing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final queueTrack = ref.watch(
      playbackQueueProvider.select((queue) => queue.currentTrack),
    );
    final track = player.track ?? queueTrack;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PanelTab(
              label: '正在播放',
              selected: _panel == _DetailPanel.player,
              onTap: () => _selectPanel(_DetailPanel.player),
            ),
            const SizedBox(width: 18),
            _PanelTab(
              label: '歌词',
              selected: _panel == _DetailPanel.lyrics,
              onTap: () => _selectPanel(_DetailPanel.lyrics),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              key: const Key('player-queue-button'),
              tooltip: '播放队列',
              onPressed: Scaffold.of(context).openEndDrawer,
              icon: const Icon(Icons.queue_music),
            ),
          ),
          IconButton(
            tooltip: _panel == _DetailPanel.player ? '查看歌词' : '查看播放',
            onPressed: () => _selectPanel(
              _panel == _DetailPanel.player
                  ? _DetailPanel.lyrics
                  : _DetailPanel.player,
            ),
            icon: Icon(
              _panel == _DetailPanel.player
                  ? Icons.lyrics_outlined
                  : Icons.album_outlined,
            ),
          ),
        ],
      ),
      endDrawer: const PlaybackQueueDrawer(),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: coralPageGradient),
        child: SafeArea(
          top: false,
          child: track == null
              ? const _NothingPlaying()
              : NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: PageView(
                    key: const Key('player-detail-pages'),
                    controller: _pageController,
                    onPageChanged: (index) {
                      final panel = _DetailPanel.values[index];
                      if (panel != _panel) setState(() => _panel = panel);
                      _pullDownDistance = 0;
                    },
                    children: [
                      PlayerControlsPanel(track: track, player: player),
                      PlayerLyricsPanel(track: track),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  void _selectPanel(_DetailPanel panel) {
    if (panel != _panel) setState(() => _panel = panel);
    _pullDownDistance = 0;
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      panel.index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_panel != _DetailPanel.player ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _pullDownDistance = 0;
    } else if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels < notification.metrics.minScrollExtent) {
      _pullDownDistance =
          notification.metrics.minScrollExtent - notification.metrics.pixels;
    } else if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      _pullDownDistance -= notification.overscroll;
    } else if (notification is ScrollEndNotification) {
      if (_pullDownDistance >= 80 && !_isClosing) {
        _isClosing = true;
        Navigator.of(context).maybePop();
      }
      _pullDownDistance = 0;
    }
    return false;
  }
}

class _PanelTab extends StatelessWidget {
  const _PanelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: selected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 16 : 0,
                height: 1,
                decoration: const BoxDecoration(
                  color: CoralPalette.brand,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ],
          ),
        ),
      );
}

class _NothingPlaying extends StatelessWidget {
  const _NothingPlaying();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.album_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                '还没有正在播放的歌曲',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('从排行榜、搜索或列表选择一首歌后，可在这里查看详情。'),
            ],
          ),
        ),
      );
}
