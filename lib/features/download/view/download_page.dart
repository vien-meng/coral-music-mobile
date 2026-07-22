import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_back_navigation.dart';
import '../../../app/audio_quality_labels.dart';
import '../../../app/cover_image.dart';
import '../../../domain/music.dart';
import '../../player/state/player_controller.dart';
import '../state/download_controller.dart';

class DownloadPage extends ConsumerWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
              child: Row(children: [
                const AppBackButton(),
                Text('下载管理',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                const Spacer(),
                IconButton(
                  tooltip: '下载说明',
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已完成的音乐可离线播放。')),
                  ),
                ),
              ]),
            ),
            if (tasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text('共 ${tasks.length} 项，下载会在本机保存。',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            Expanded(
              child: tasks.isEmpty
                  ? const _EmptyDownloads()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _DownloadRow(task: tasks[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.download_outlined,
              size: 34, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          const Text('还没有下载任务'),
          const SizedBox(height: 4),
          Text('从歌曲列表或播放页添加下载。', style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.task});

  final DownloadTask task;
  static const _directoryChannel = MethodChannel('coral_music/downloads');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(downloadProvider.notifier);
    final isActive = task.status == DownloadStatus.downloading;
    final fileName = task.targetPath.isEmpty
        ? null
        : File(task.targetPath).uri.pathSegments.last;
    final extension = _extension(fileName);
    final tasks = ref.watch(downloadProvider);
    final configuredDirectory = ref.watch(downloadDirectoryProvider);
    final canMoveToConfiguredDirectory = !Platform.isIOS &&
        (configuredDirectory == null ||
            task.targetPath.isEmpty ||
            File(task.targetPath).parent.absolute.path !=
                Directory(configuredDirectory).absolute.path);
    final upgrades = task.status == DownloadStatus.completed
        ? AudioQuality.values
            .where((quality) =>
                quality.index < task.quality.index &&
                task.track.availableQualities.contains(quality) &&
                DownloadController.canEnqueueQuality(
                  tasks,
                  task.track,
                  quality,
                ))
            .toList(growable: false)
        : const <AudioQuality>[];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: task.status != DownloadStatus.completed || task.targetPath.isEmpty
          ? null
          : () => ref.read(playerProvider.notifier).playTrack(
                Track(
                  sourceKind: TrackSourceKind.download,
                  sourceId: task.track.sourceId,
                  sourceTrackId: task.track.sourceTrackId,
                  title: task.track.title,
                  artist: task.track.artist,
                  album: task.track.album,
                  duration: task.track.duration,
                  coverUri: task.track.coverUri,
                  localUri: Uri.file(task.targetPath),
                  availableQualities: [task.quality],
                ),
              ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(children: [
          _DownloadArtwork(uri: task.track.coverUri),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fileName ?? task.track.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(
                [
                  task.error ?? _label(task.status),
                  if (task.status != DownloadStatus.completed)
                    '${(task.progress * 100).round()}%',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '音质：${audioQualityLabel(task.quality)} · 格式：${extension ?? '未知'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (isActive) ...[
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    minHeight: 2,
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 4),
          if (isActive)
            IconButton(
              tooltip: '暂停下载',
              icon: const Icon(Icons.pause_outlined),
              onPressed: () => controller.pause(task.id),
            )
          else if (task.status == DownloadStatus.paused ||
              task.status == DownloadStatus.failed)
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: '继续下载',
                icon: const Icon(Icons.play_arrow_outlined),
                onPressed: () => controller.resume(task),
              ),
              if (task.status == DownloadStatus.failed)
                IconButton(
                  tooltip: '删除失败下载',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => controller.remove(task),
                ),
            ])
          else if (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.cancelled)
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (upgrades.isNotEmpty)
                IconButton(
                  tooltip: '升级音质',
                  icon: const Icon(Icons.upgrade),
                  onPressed: () => _upgrade(context, controller, upgrades),
                ),
              if (task.status == DownloadStatus.completed)
                PopupMenuButton<_CompletedAction>(
                  tooltip: '更多操作',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (action) {
                    switch (action) {
                      case _CompletedAction.moveToDownloadDirectory:
                        _moveToDownloadDirectory(context, controller);
                      case _CompletedAction.openDirectory:
                        _openDirectory(context);
                      case _CompletedAction.remove:
                        controller.remove(task);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _CompletedAction.openDirectory,
                      child: _OpenDirectoryMenuItem(),
                    ),
                    if (canMoveToConfiguredDirectory)
                      const PopupMenuItem(
                        value: _CompletedAction.moveToDownloadDirectory,
                        child: Row(children: [
                          Icon(Icons.drive_file_move_outlined),
                          SizedBox(width: 12),
                          Text('移到设置下载目录'),
                        ]),
                      ),
                    const PopupMenuItem(
                      value: _CompletedAction.remove,
                      child: Row(children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 12),
                        Text('移除下载'),
                      ]),
                    ),
                  ],
                )
              else
                IconButton(
                  tooltip: '移除下载',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => controller.remove(task),
                ),
            ])
          else
            const Icon(Icons.download_outlined),
        ]),
      ),
    );
  }

  String _label(DownloadStatus status) => switch (status) {
        DownloadStatus.queued => '等待下载',
        DownloadStatus.downloading => '正在下载',
        DownloadStatus.paused => '已暂停',
        DownloadStatus.completed => '已完成',
        DownloadStatus.failed => '下载失败',
        DownloadStatus.cancelled => '已取消',
      };

  String? _extension(String? fileName) {
    if (fileName == null) return null;
    final dot = fileName.lastIndexOf('.');
    if (dot < 1 || dot == fileName.length - 1) return null;
    return fileName.substring(dot + 1).toUpperCase();
  }

  Future<void> _upgrade(
    BuildContext context,
    DownloadController controller,
    List<AudioQuality> qualities,
  ) async {
    final quality = await showModalBottomSheet<AudioQuality>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: const Text('升级下载音质'),
              subtitle: Text('当前 ${audioQualityLabel(task.quality)}'),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in qualities)
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: Text(audioQualityLabel(item)),
                      subtitle: Text(audioQualityDescription(item)),
                      onTap: () => Navigator.pop(sheetContext, item),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
    if (quality == null) return;
    final added = await controller.enqueue(task.track, quality: quality);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added
            ? '已加入 ${audioQualityLabel(quality)} 下载任务'
            : '相同或更高音质已在下载列表中'),
      ),
    );
  }

  Future<void> _moveToDownloadDirectory(
    BuildContext context,
    DownloadController controller,
  ) async {
    final result = await controller.moveToConfiguredDirectory(task);
    if (!context.mounted) return;
    final message = switch (result) {
      MoveDownloadResult.moved => '已移到设置下载目录。',
      MoveDownloadResult.alreadyInDirectory => '文件已在设置下载目录。',
      MoveDownloadResult.noConfiguredDirectory => '请先在设置中选择下载目录。',
      MoveDownloadResult.sourceMissing => '下载文件不存在，无法移动。',
      MoveDownloadResult.failed => '移动失败，请检查设置目录权限。',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDirectory(BuildContext context) async {
    if (Platform.isIOS) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('在文件 App 中查看'),
          content: const Text(
            '下载已开放给系统文件 App。请打开“文件”→“浏览”→“我的 iPhone”→“珊瑚音乐”→“downloads”。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    final directory = File(task.targetPath).parent;
    if (task.targetPath.isEmpty || !await directory.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('下载目录不存在。')));
      }
      return;
    }
    if (Platform.isAndroid) {
      try {
        final opened = await _directoryChannel.invokeMethod<bool>(
              'openDirectory',
              {'path': directory.path},
            ) ??
            false;
        if (opened || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('默认下载目录仅应用可访问，请导出或选择公共下载目录。')),
        );
        return;
      } on PlatformException {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('无法打开系统文件管理器。')));
        }
        return;
      }
    }
    await FilePicker.platform.getDirectoryPath(
      dialogTitle: '打开所在目录',
      initialDirectory: directory.path,
    );
  }
}

enum _CompletedAction { openDirectory, moveToDownloadDirectory, remove }

class _OpenDirectoryMenuItem extends StatelessWidget {
  const _OpenDirectoryMenuItem();

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.folder_open_outlined),
        const SizedBox(width: 12),
        Text(Platform.isIOS ? '在文件 App 中查看' : '打开所在目录'),
      ]);
}

class _DownloadArtwork extends StatelessWidget {
  const _DownloadArtwork({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 46,
          height: 46,
          child: CoverImage(
            uri: uri,
            fallback: ColoredBox(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.music_note_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
}
