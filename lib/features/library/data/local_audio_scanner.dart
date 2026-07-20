import 'dart:io';

import '../../../domain/music.dart';
import '../../player/data/audio_file_probe.dart';
import 'cue_parser.dart';
import 'local_audio_metadata.dart';

final class LocalAudioScanResult {
  const LocalAudioScanResult({required this.tracks, required this.skipped});

  final List<Track> tracks;
  final List<String> skipped;
}

final class LocalAudioScanner {
  static const _extensions = {
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
    'ape',
    'aiff',
    'alac'
  };
  static const _coverNames = {
    'cover.jpg',
    'cover.jpeg',
    'cover.png',
    'folder.jpg',
    'folder.jpeg',
    'folder.png',
  };
  static const _sidecarExtensions = {
    'cue',
    'lrc',
    'jpg',
    'jpeg',
    'png',
    'webp'
  };
  final _covers = <String, Future<Uri?>>{};
  final _probes = <String, Future<AudioFileInfo>>{};

  Future<LocalAudioScanResult> scanFiles(Iterable<String> paths) async {
    final tracks = <Track>[];
    final skipped = <String>[];
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists() || !_isAudio(path)) {
        skipped.add(path);
        continue;
      }
      tracks.add(await _track(file));
    }
    return LocalAudioScanResult(tracks: tracks, skipped: skipped);
  }

  Future<LocalAudioScanResult> scanDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      return LocalAudioScanResult(tracks: const [], skipped: [path]);
    }
    final tracks = <Track>[];
    final skipped = <String>[];
    final files = <File>[];
    try {
      await for (final entry
          in directory.list(recursive: true, followLinks: false)) {
        if (entry is File) files.add(entry);
      }
      final cueMedia = <String>{};
      for (final entry
          in files.where((file) => file.path.toLowerCase().endsWith('.cue'))) {
        try {
          final cueTracks = await CueParser().parse(entry);
          tracks.addAll(await Future.wait(cueTracks.map(_enrichCueTrack)));
          cueMedia.addAll(cueTracks
              .map((track) => track.localUri?.toFilePath())
              .whereType<String>());
        } on FileSystemException {
          skipped.add(entry.path);
        }
      }
      for (final entry
          in files.where((file) => !file.path.toLowerCase().endsWith('.cue'))) {
        if (_isAudio(entry.path) && !cueMedia.contains(entry.absolute.path)) {
          tracks.add(await _track(entry));
        } else if (!_isSidecar(entry.path) && !_isAudio(entry.path)) {
          skipped.add(entry.path);
        }
      }
    } on FileSystemException {
      skipped.add(path);
    }
    return LocalAudioScanResult(tracks: tracks, skipped: skipped);
  }

  bool _isAudio(String path) =>
      _extensions.contains(path.split('.').last.toLowerCase());

  bool _isSidecar(String path) =>
      _sidecarExtensions.contains(path.split('.').last.toLowerCase());

  Future<Track> _track(File file) async {
    final name = file.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final parts = base.split(RegExp(r'\s+-\s+'));
    final artist = parts.length > 1 ? parts.first : '';
    final title = parts.length > 1 ? parts.sublist(1).join(' - ') : base;
    final metadata = await readLocalAudioMetadata(file);
    final sidecarCover = await _coverFor(file.parent);
    return Track(
      sourceKind: TrackSourceKind.local,
      sourceId: 'device',
      sourceTrackId: file.absolute.path,
      title: metadata.title ?? title,
      artist: metadata.artist ?? artist,
      album: metadata.album,
      localUri: file.absolute.uri,
      coverUri: sidecarCover ?? await cacheEmbeddedArtwork(file, metadata),
      extra: metadata.extra,
    );
  }

  Future<Track> _enrichCueTrack(Track track) async {
    final uri = track.localUri;
    if (uri == null) return track;
    final cover = await _coverFor(File.fromUri(uri).parent);
    final info = await _probes.putIfAbsent(
      uri.toString(),
      () => HttpAudioFileProbe().probe(uri),
    );
    final start = track.extra['cueStartMs'];
    final startDuration = start is int ? Duration(milliseconds: start) : null;
    final end = track.extra['cueEndMs'];
    final derivedEnd = end is int ? Duration(milliseconds: end) : info.duration;
    final duration = track.duration ??
        (startDuration != null &&
                derivedEnd != null &&
                derivedEnd > startDuration
            ? derivedEnd - startDuration
            : null);
    final extra = {
      ...track.extra,
      if (end is! int && derivedEnd != null)
        'cueEndMs': derivedEnd.inMilliseconds,
    };
    return Track(
      sourceKind: track.sourceKind,
      sourceId: track.sourceId,
      sourceTrackId: track.sourceTrackId,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: duration,
      coverUri: cover,
      localUri: uri,
      availableQualities: track.availableQualities,
      extra: extra,
    );
  }

  Future<Uri?> _coverFor(Directory directory) => _covers.putIfAbsent(
        directory.path,
        () async {
          try {
            await for (final entry in directory.list(followLinks: false)) {
              if (entry is File &&
                  _coverNames.contains(
                    entry.uri.pathSegments.last.toLowerCase(),
                  )) {
                return entry.absolute.uri;
              }
            }
          } on FileSystemException {
            // The audio remains importable when sidecar art cannot be read.
          }
          return null;
        },
      );
}
