import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/cover_image.dart';
import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../data/lyric_timeline.dart';
import '../state/lyric_controller.dart';
import '../state/player_controller.dart';
import 'player_transport_controls.dart';

class PlayerLyricsPanel extends ConsumerStatefulWidget {
  const PlayerLyricsPanel({required this.track, super.key});

  final Track track;

  @override
  ConsumerState<PlayerLyricsPanel> createState() => _PlayerLyricsPanelState();
}

class _PlayerLyricsPanelState extends ConsumerState<PlayerLyricsPanel> {
  final _scrollController = ScrollController();
  final _lineKeys = <int, GlobalKey>{};
  var _activeLine = -1;
  var _isRetrying = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final lyric = ref.watch(lyricProvider(track));
    final player = ref.watch(playerProvider);
    final position =
        player.track?.id == track.id ? player.position : Duration.zero;
    return Padding(
      key: const ValueKey('lyrics-panel'),
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
        24,
        14,
      ),
      child: Column(
        children: [
          _LyricTrackHeader(track: track),
          const SizedBox(height: 14),
          Expanded(
            child: lyric.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_isRetrying ? '正在重新加载歌词' : '正在加载歌词'),
                  ],
                ),
              ),
              error: (error, _) => _LyricError(
                message: _lyricErrorMessage(error),
                onRetry: _retry,
              ),
              data: (payload) {
                final lines = payload == null
                    ? const <LyricLine>[]
                    : parseLyricTimeline(payload);
                if (lines.isEmpty) {
                  final plainLines = payload == null
                      ? const <String>[]
                      : parsePlainLyricLines(payload);
                  if (plainLines.isNotEmpty) {
                    return _PlainLyrics(lines: plainLines);
                  }
                  return _LyricEmpty(onRetry: _retry);
                }
                var active = 0;
                for (var index = 0; index < lines.length; index++) {
                  if (lines[index].at <= position) active = index;
                }
                if (active != _activeLine) {
                  _activeLine = active;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_scrollController.hasClients) return;
                    final targetContext = _lineKeys[active]?.currentContext;
                    if (targetContext != null) {
                      Scrollable.ensureVisible(
                        targetContext,
                        alignment: .5,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                      return;
                    }
                    // ponytail: only used until ListView builds an off-screen active line.
                    _scrollController.animateTo(
                      (active * 48.0).clamp(
                        0.0,
                        _scrollController.position.maxScrollExtent,
                      ),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                    );
                  });
                }
                return LayoutBuilder(
                  builder: (context, constraints) => ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: constraints.maxHeight * .36,
                    ),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      final isActive = index == active;
                      return KeyedSubtree(
                        key: _lineKeys.putIfAbsent(index, GlobalKey.new),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Column(
                            children: [
                              Text.rich(
                                line.words.isEmpty || !isActive
                                    ? TextSpan(text: line.text)
                                    : TextSpan(
                                        children: line.words
                                            .expand(
                                              (word) => _karaokeWordSpans(
                                                context,
                                                word,
                                                position,
                                              ),
                                            )
                                            .toList(growable: false),
                                      ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: isActive
                                          ? CoralPalette.player
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: .52),
                                      fontWeight: isActive
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                              ),
                              if (line.translation case final translation?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    translation,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              if (line.romanization case final romanization?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    romanization,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          PlayerTransportControls(
            key: const ValueKey('lyrics-player-controls'),
            track: track,
            player: player,
            toggleKey: const Key('lyrics-player-toggle'),
          ),
        ],
      ),
    );
  }

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      final lyric = await ref.refresh(lyricProvider(widget.track).future);
      if (!mounted || lyric != null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仍未找到可用歌词')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('歌词重试失败：${_lyricErrorMessage(error)}')),
      );
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }
}

class _PlainLyrics extends StatelessWidget {
  const _PlainLyrics({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 24),
        itemCount: lines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, index) => Text(
          lines[index],
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _LyricTrackHeader extends StatelessWidget {
  const _LyricTrackHeader({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) => Row(
        key: const ValueKey('lyrics-track-header'),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(
              dimension: 58,
              child: CoverImage(
                uri: track.coverUri,
                fallback: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.music_note_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  track.artist.isEmpty ? '未知歌手' : track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
}

List<TextSpan> _karaokeWordSpans(
  BuildContext context,
  LyricWord word,
  Duration position,
) {
  final elapsed = position - word.start;
  final duration = word.duration.inMilliseconds;
  final progress = elapsed.inMilliseconds <= 0
      ? 0.0
      : (elapsed.inMilliseconds / (duration == 0 ? 1 : duration))
          .clamp(0.0, 1.0);
  final characters = word.text.runes.map(String.fromCharCode).toList();
  if (characters.isEmpty) return const [];
  final filled = progress * characters.length;
  final muted =
      Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .62);
  return List.generate(characters.length, (index) {
    final characterProgress = (filled - index).clamp(0.0, 1.0);
    return TextSpan(
      text: characters[index],
      style: TextStyle(
        color: Color.lerp(muted, CoralPalette.player, characterProgress),
        fontWeight: characterProgress > 0 ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  });
}

class _LyricEmpty extends StatelessWidget {
  const _LyricEmpty({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('暂无可用歌词'),
            const SizedBox(height: 6),
            const Text('独立歌词服务未找到匹配结果'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载歌词'),
            ),
          ],
        ),
      );
}

class _LyricError extends StatelessWidget {
  const _LyricError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lyrics_outlined, size: 44),
              const SizedBox(height: 12),
              const Text('歌词加载失败'),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新加载歌词'),
              ),
            ],
          ),
        ),
      );
}

String _lyricErrorMessage(Object error) =>
    error is AppFailure ? error.message : '音源未返回可用歌词';
