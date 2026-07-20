import 'dart:io';

import 'package:coral_music_mobile/domain/music.dart';
import 'package:coral_music_mobile/features/download/state/download_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = Track(
    sourceKind: TrackSourceKind.online,
    sourceId: 'kw',
    sourceTrackId: '1',
    title: '测试',
    artist: '',
  );

  DownloadTask task(DownloadStatus status, String path) => DownloadTask(
        id: 'task',
        track: track,
        quality: AudioQuality.flac,
        status: status,
        targetPath: path,
        createdAt: DateTime(2026),
      );

  test('startup restoration pauses unfinished tasks and detects missing files',
      () async {
    final directory = await Directory.systemTemp.createTemp('coral-download-');
    try {
      final completed = File('${directory.path}/done.flac');
      await completed.writeAsBytes([0]);

      expect(
        (await DownloadController.restoreForStartup(
          task(DownloadStatus.downloading, '${directory.path}/partial.flac'),
        ))
            .status,
        DownloadStatus.paused,
      );
      expect(
        (await DownloadController.restoreForStartup(
          task(DownloadStatus.completed, completed.path),
        ))
            .status,
        DownloadStatus.completed,
      );
      expect(
        (await DownloadController.restoreForStartup(
          task(DownloadStatus.completed, '${directory.path}/missing.flac'),
        ))
            .status,
        DownloadStatus.failed,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('uses a readable download filename without overwriting files', () async {
    final directory = await Directory.systemTemp.createTemp('coral-download-');
    try {
      final first = await DownloadController.nextTargetPath(
        directory,
        track,
        'flac',
      );
      expect(first, '${directory.path}/测试.flac');
      await File(first).writeAsBytes([0]);
      await File('${directory.path}/测试 (2).flac.part').writeAsBytes([0]);

      expect(
        await DownloadController.nextTargetPath(directory, track, 'flac'),
        '${directory.path}/测试 (3).flac',
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
