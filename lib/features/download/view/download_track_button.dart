import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/music.dart';
import '../state/download_controller.dart';

class DownloadTrackButton extends ConsumerStatefulWidget {
  const DownloadTrackButton({
    required this.track,
    this.showLabel = false,
    this.compact = false,
    super.key,
  });

  final Track track;
  final bool showLabel;
  final bool compact;

  @override
  ConsumerState<DownloadTrackButton> createState() =>
      _DownloadTrackButtonState();
}

class _DownloadTrackButtonState extends ConsumerState<DownloadTrackButton> {
  var _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(
      downloadProvider.select((tasks) => _statusFor(tasks, widget.track.id)),
    );
    final completed = status == DownloadStatus.completed;
    final active = _isSubmitting ||
        status == DownloadStatus.queued ||
        status == DownloadStatus.downloading;
    final paused = status == DownloadStatus.paused;
    final label = completed
        ? '已下载'
        : active
            ? '下载中'
            : paused
                ? '已暂停'
                : '下载';
    final button = SizedBox.square(
      dimension: widget.compact ? 40 : 48,
      child: IconButton(
        style: widget.compact
            ? IconButton.styleFrom(
                minimumSize: const Size.square(40),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : null,
        key: ValueKey('download-${widget.track.id}'),
        tooltip: label,
        onPressed: active ? null : _enqueue,
        icon: active
            ? SizedBox.square(
                key: ValueKey('download-active-${widget.track.id}'),
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Icon(
                completed
                    ? Icons.check_rounded
                    : paused
                        ? Icons.pause_circle_outline
                        : Icons.download_outlined,
                color: completed || paused
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
      ),
    );
    if (!widget.showLabel) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 3),
        FittedBox(
          child: Text(label,
              maxLines: 1, style: Theme.of(context).textTheme.labelSmall),
        ),
      ],
    );
  }

  Future<void> _enqueue() async {
    setState(() => _isSubmitting = true);
    var added = false;
    var failed = false;
    try {
      added = await ref.read(downloadProvider.notifier).enqueue(widget.track);
    } on Object {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    final status = _statusFor(ref.read(downloadProvider), widget.track.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failed
            ? '加入下载任务失败'
            : added
                ? '已加入下载任务'
                : status == DownloadStatus.completed
                    ? '这首歌已下载'
                    : status != null
                        ? '这首歌已在下载列表中'
                        : '当前歌曲不可下载'),
        action: added
            ? SnackBarAction(
                label: '查看',
                onPressed: () => context.go('/download'),
              )
            : null,
      ),
    );
  }
}

DownloadStatus? _statusFor(Iterable<DownloadTask> tasks, String trackId) {
  for (final task in tasks) {
    if (task.track.id == trackId &&
        task.status != DownloadStatus.failed &&
        task.status != DownloadStatus.cancelled) {
      return task.status;
    }
  }
  return null;
}
