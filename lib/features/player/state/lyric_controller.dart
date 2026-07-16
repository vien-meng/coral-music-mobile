import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../data/local_lyric_loader.dart';
import 'player_controller.dart';

final lyricProvider =
    FutureProvider.family<LyricPayload?, Track>((ref, track) async {
  final local = await LocalLyricLoader().load(track);
  if (local != null || track.sourceKind != TrackSourceKind.online) return local;
  return ref.watch(userApiRunnerProvider).resolveLyric(track);
});
