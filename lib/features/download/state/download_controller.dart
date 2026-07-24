import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import '../../../platform/ohos_file_access.dart';
import '../../library/data/library_store.dart';
import '../../player/data/playback_resolver.dart';
import '../../player/state/player_controller.dart';

final downloadProvider =
    StateNotifierProvider<DownloadController, List<DownloadTask>>(
  (ref) => DownloadController(
    ref.watch(playbackResolverProvider),
    ref.watch(libraryStoreProvider),
    ref.read(downloadDirectoryProvider.notifier),
  ),
);

final downloadDirectoryProvider =
    StateNotifierProvider<DownloadDirectoryController, String?>(
  (ref) => DownloadDirectoryController(ref.watch(libraryStoreProvider)),
);

final class DownloadDirectoryController extends StateNotifier<String?> {
  DownloadDirectoryController(this._store) : super(null) {
    _ready = _load();
  }

  final LibraryStore _store;
  late final Future<void> _ready;

  Future<void> _load() async {
    final saved = await _store.downloadDirectory();
    if (Platform.isIOS || OhosFileAccess.isOhos) {
      // iOS document-provider paths are not persistently writable from Dart.
      if (saved != null) await _store.saveDownloadDirectory(null);
      state = null;
      return;
    }
    state = saved;
  }

  Future<Directory> _applicationDownloads() async {
    final documents = await OhosFileAccess.applicationDocumentsDirectory();
    return Directory('${documents.path}/downloads');
  }

  Future<bool> useApplicationDirectory() async {
    await _ready;
    try {
      await (await _applicationDownloads()).create(recursive: true);
    } on FileSystemException {
      return false;
    }
    await _store.saveDownloadDirectory(null);
    state = null;
    return true;
  }

  Future<bool> setDirectory(String path) async {
    if (Platform.isIOS || OhosFileAccess.isOhos) {
      return useApplicationDirectory();
    }
    final directory = Directory(path);
    try {
      await directory.create(recursive: true);
    } on FileSystemException {
      return false;
    }
    await _store.saveDownloadDirectory(directory.path);
    state = directory.path;
    return true;
  }

  Future<Directory> resolve() async {
    await _ready;
    if (!Platform.isIOS && !OhosFileAccess.isOhos && state != null) {
      return Directory(state!);
    }
    return _applicationDownloads();
  }

  Future<Directory?> configured() async {
    await _ready;
    if (Platform.isIOS || OhosFileAccess.isOhos) return resolve();
    return state == null ? null : Directory(state!);
  }
}

final class DownloadController extends StateNotifier<List<DownloadTask>> {
  DownloadController(this._resolver, this._store, this._directory)
      : super(const []) {
    _ready = load();
  }

  final PlaybackResolver _resolver;
  final LibraryStore _store;
  final DownloadDirectoryController _directory;
  late final Future<void> _ready;
  final _cancelTokens = <String, CancelToken>{};
  final _paused = <String>{};
  final _waiting = <DownloadTask>[];
  var _draining = false;

  Future<bool> enqueue(Track track, {AudioQuality? quality}) async {
    await _ready;
    if (track.sourceKind != TrackSourceKind.online &&
        track.sourceKind != TrackSourceKind.webdav) {
      return false;
    }
    if (!canEnqueueQuality(state, track, quality)) return false;
    final selectedQuality =
        quality ?? defaultPlaybackQuality(track.availableQualities);
    final id = '${track.id}:${DateTime.now().microsecondsSinceEpoch}';
    final task = DownloadTask(
      id: id,
      track: track,
      quality: selectedQuality,
      status: DownloadStatus.queued,
      targetPath: '',
      createdAt: DateTime.now(),
    );
    _set(task);
    _schedule(task);
    return true;
  }

  static bool canEnqueueQuality(
    Iterable<DownloadTask> tasks,
    Track track,
    AudioQuality? quality,
  ) =>
      !tasks.any(
        (task) =>
            task.track.id == track.id &&
            task.status != DownloadStatus.failed &&
            task.status != DownloadStatus.cancelled &&
            (task.status != DownloadStatus.completed ||
                quality == null ||
                task.quality.index <= quality.index),
      );

  Future<({int added, int skipped})> enqueueAll(Iterable<Track> tracks) async {
    var added = 0;
    var skipped = 0;
    for (final track in tracks) {
      if (await enqueue(track)) {
        added++;
      } else {
        skipped++;
      }
    }
    return (added: added, skipped: skipped);
  }

  Future<void> load() async {
    final saved = await _store.listDownloadTasks();
    final restored = await Future.wait(saved.map(restoreForStartup));
    state = restored;
    for (var index = 0; index < restored.length; index++) {
      final before = saved[index];
      final after = restored[index];
      if (before.status != after.status || before.error != after.error) {
        unawaited(_store.saveDownloadTask(after));
      }
    }
  }

  static Future<DownloadTask> restoreForStartup(DownloadTask task) async {
    if (task.status == DownloadStatus.completed &&
        (task.targetPath.isEmpty || !await File(task.targetPath).exists())) {
      return DownloadTask(
        id: task.id,
        track: task.track,
        quality: task.quality,
        status: DownloadStatus.failed,
        targetPath: task.targetPath,
        createdAt: task.createdAt,
        progress: 0,
        error: '下载文件不存在，请重新下载',
      );
    }
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.queued) {
      return DownloadTask(
        id: task.id,
        track: task.track,
        quality: task.quality,
        status: DownloadStatus.paused,
        targetPath: task.targetPath,
        createdAt: task.createdAt,
        progress: task.progress,
      );
    }
    return task;
  }

  static Future<String> nextTargetPath(
    Directory directory,
    Track track,
    String extension,
  ) async {
    final title = _safeName(track.title);
    final artist = _safeName(track.artist);
    final base = artist.isEmpty ? title : '$title - $artist';
    for (var suffix = 1;; suffix++) {
      final name = suffix == 1 ? base : '$base ($suffix)';
      final path = '${directory.path}/$name.$extension';
      if (!await File(path).exists() && !await File('$path.part').exists()) {
        return path;
      }
    }
  }

  static Future<String> moveFile(
    File source,
    Directory directory,
    Track track,
  ) async {
    final dot = source.path.lastIndexOf('.');
    final extension = dot < 1 ? 'mp3' : source.path.substring(dot + 1);
    final target = await nextTargetPath(directory, track, extension);
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target);
      await source.delete();
    }
    return target;
  }

  Future<void> resume(DownloadTask task) async {
    if (_cancelTokens.containsKey(task.id) ||
        _waiting.any((waiting) => waiting.id == task.id)) {
      return;
    }
    final queued = _task(task, status: DownloadStatus.queued);
    _replace(queued, status: DownloadStatus.queued);
    _schedule(queued);
  }

  Future<void> pause(String id) async {
    _paused.add(id);
    _cancelTokens[id]?.cancel();
    final waiting = _waiting.where((task) => task.id == id).toList();
    _waiting.removeWhere((task) => task.id == id);
    for (final task in waiting) {
      _replace(task, status: DownloadStatus.paused);
    }
  }

  Future<void> cancel(String id) async {
    _paused.remove(id);
    _cancelTokens.remove(id)?.cancel();
    final waiting = _waiting.where((task) => task.id == id).toList();
    _waiting.removeWhere((task) => task.id == id);
    for (final task in waiting) {
      _replace(task, status: DownloadStatus.cancelled, error: null);
      unawaited(_deleteTemporary(task.targetPath));
    }
  }

  Future<void> remove(DownloadTask task) async {
    await cancel(task.id);
    try {
      if (task.targetPath.isNotEmpty) await File(task.targetPath).delete();
    } on FileSystemException {
      // ponytail: removal is idempotent when the system has already cleared app files.
    }
    await _store.deleteDownloadTask(task.id);
    state = state.where((item) => item.id != task.id).toList(growable: false);
  }

  Future<MoveDownloadResult> moveToConfiguredDirectory(
      DownloadTask task) async {
    final destination = await _directory.configured();
    if (destination == null) return MoveDownloadResult.noConfiguredDirectory;
    final source = File(task.targetPath);
    if (task.targetPath.isEmpty || !await source.exists()) {
      return MoveDownloadResult.sourceMissing;
    }
    try {
      final directory = await destination.create(recursive: true);
      if (source.parent.absolute.path == directory.absolute.path) {
        return MoveDownloadResult.alreadyInDirectory;
      }
      final target = await moveFile(source, directory, task.track);
      final moved = _task(task, status: task.status, targetPath: target);
      state = [
        for (final item in state)
          if (item.id == task.id) moved else item,
      ];
      await _store.saveDownloadTask(moved);
      return MoveDownloadResult.moved;
    } on FileSystemException {
      return MoveDownloadResult.failed;
    }
  }

  void _schedule(DownloadTask task) {
    _waiting.add(task);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    while (_waiting.isNotEmpty) {
      await _download(_waiting.removeAt(0));
    }
    _draining = false;
  }

  Future<void> _download(DownloadTask task) async {
    final token = CancelToken();
    var current = task;
    _cancelTokens[task.id] = token;
    _replace(task, status: DownloadStatus.downloading);
    try {
      final playback =
          await _resolver.resolve(task.track, quality: task.quality);
      final downloads =
          await (await _directory.resolve()).create(recursive: true);
      final extension = _extension(playback.uri);
      final target = task.targetPath.isNotEmpty
          ? task.targetPath
          : await nextTargetPath(downloads, task.track, extension);
      final temporary = '$target.part';
      final offset = await File(temporary).length().onError((_, __) => 0);
      current = _task(task,
          status: DownloadStatus.downloading,
          quality: playback.quality ?? task.quality,
          targetPath: target,
          progress: offset == 0 ? 0 : task.progress);
      _replace(current,
          status: DownloadStatus.downloading,
          targetPath: target,
          progress: offset == 0 ? 0 : task.progress);
      final response = await Dio().download(
        playback.uri.toString(),
        temporary,
        cancelToken: token,
        options: Options(headers: {
          ...playback.headers,
          if (offset > 0) 'Range': 'bytes=$offset-',
        }),
        fileAccessMode:
            offset > 0 ? FileAccessMode.append : FileAccessMode.write,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _replace(current,
                status: DownloadStatus.downloading,
                targetPath: target,
                progress: (offset + received) / (offset + total));
          }
        },
      );
      if (offset > 0 && response.statusCode != 206) {
        await File(temporary).delete();
        return _download(_task(current,
            status: DownloadStatus.queued, targetPath: target, progress: 0));
      }
      await File(temporary).rename(target);
      _replace(current,
          status: DownloadStatus.completed, targetPath: target, progress: 1);
    } on DioException catch (error) {
      final cancelled = CancelToken.isCancel(error);
      final paused = cancelled && _paused.remove(task.id);
      if (cancelled && !paused) unawaited(_deleteTemporary(current.targetPath));
      _replace(current,
          status: paused
              ? DownloadStatus.paused
              : cancelled
                  ? DownloadStatus.cancelled
                  : DownloadStatus.failed,
          error: cancelled ? null : '下载失败');
    } on AppFailure catch (error) {
      _replace(current, status: DownloadStatus.failed, error: error.message);
    } on Object {
      _replace(current, status: DownloadStatus.failed, error: '下载失败');
    } finally {
      _cancelTokens.remove(task.id);
    }
  }

  void _replace(
    DownloadTask task, {
    required DownloadStatus status,
    String? targetPath,
    double? progress,
    String? error,
  }) {
    final next = _task(
      task,
      status: status,
      targetPath: targetPath,
      progress: progress,
      error: error,
    );
    state = [
      for (final item in state)
        if (item.id == task.id) next else item,
    ];
    unawaited(_store.saveDownloadTask(next));
  }

  void _set(DownloadTask task) {
    state = [task, ...state];
    unawaited(_store.saveDownloadTask(task));
  }

  DownloadTask _task(
    DownloadTask task, {
    required DownloadStatus status,
    AudioQuality? quality,
    String? targetPath,
    double? progress,
    String? error,
  }) =>
      DownloadTask(
        id: task.id,
        track: task.track,
        quality: quality ?? task.quality,
        status: status,
        targetPath: targetPath ?? task.targetPath,
        createdAt: task.createdAt,
        progress: progress ?? task.progress,
        error: error,
      );

  static String _safeName(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  Future<void> _deleteTemporary(String targetPath) async {
    if (targetPath.isEmpty) return;
    try {
      await File('$targetPath.part').delete();
    } on FileSystemException {
      // ponytail: a missing temporary file is already the desired cancelled state.
    }
  }

  String _extension(Uri uri) {
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = last.lastIndexOf('.');
    return dot > 0 && dot < last.length - 1 ? last.substring(dot + 1) : 'mp3';
  }
}

enum MoveDownloadResult {
  moved,
  alreadyInDirectory,
  noConfiguredDirectory,
  sourceMissing,
  failed,
}
