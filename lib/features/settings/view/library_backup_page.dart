import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/data/library_backup_codec.dart';
import '../../library/state/library_controller.dart';

class LibraryBackupPage extends ConsumerStatefulWidget {
  const LibraryBackupPage({super.key});

  @override
  ConsumerState<LibraryBackupPage> createState() => _LibraryBackupPageState();
}

class _LibraryBackupPageState extends ConsumerState<LibraryBackupPage> {
  LibraryBackup? _preview;
  var _isWorking = false;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('资料备份', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('备份仅保存在你选择的位置，不会上传到任何服务器。'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isWorking ? null : _export,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('导出本机资料备份'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isWorking ? null : _chooseBackup,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('选择备份文件恢复'),
          ),
          if (_preview case final backup?) ...[
            const SizedBox(height: 24),
            Text('恢复预览', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _PreviewCard(backup: backup),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isWorking ? null : () => _restore(backup),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('合并恢复到本机'),
            ),
            const SizedBox(height: 8),
            const Text('恢复只新增资料，不覆盖现有列表或收藏。', textAlign: TextAlign.center),
          ],
        ],
      );

  Future<void> _export() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出资料备份',
      fileName: 'coral-music-backup.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return;
    setState(() => _isWorking = true);
    try {
      await File(path).writeAsString(
        await ref.read(libraryProvider.notifier).exportLibraryBackup(),
        flush: true,
      );
      if (mounted) _show('资料备份已导出。');
    } on Object {
      if (mounted) _show('导出备份失败。');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _chooseBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final file =
        result == null || result.files.isEmpty ? null : result.files.first;
    if (file == null) return;
    if (file.size > 8 * 1024 * 1024) {
      _show('备份文件不能超过 8 MB。');
      return;
    }
    setState(() => _isWorking = true);
    try {
      final raw = file.bytes == null
          ? await File(file.path!).readAsString()
          : utf8.decode(file.bytes!);
      final backup =
          ref.read(libraryProvider.notifier).previewLibraryBackup(raw);
      if (mounted) setState(() => _preview = backup);
    } on Object {
      if (mounted) _show('备份文件无效或已损坏。');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _restore(LibraryBackup backup) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('合并恢复资料？'),
        content: const Text('将新增列表和缺失的收藏，不会覆盖当前资料。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _isWorking = true);
    final result =
        await ref.read(libraryProvider.notifier).restoreLibraryBackup(backup);
    if (mounted) {
      setState(() {
        _isWorking = false;
        if (result != null) _preview = null;
      });
      if (result != null) {
        _show('已恢复 ${result.playlists} 个列表、${result.tracks} 首歌曲。');
      }
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.backup});

  final LibraryBackup backup;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${backup.playlists.length} 个列表 · ${backup.trackCount} 首歌曲'),
              const SizedBox(height: 6),
              Text('歌曲收藏 ${backup.favorites.length} · '
                  '歌单收藏 ${backup.onlineFavorites.length} · '
                  '不感兴趣 ${backup.ignoredTracks.length}'),
            ],
          ),
        ),
      );
}
