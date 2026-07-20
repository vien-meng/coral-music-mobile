import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/music.dart';
import '../data/local_lyric_loader.dart';
import '../data/kuwo_lyric_service.dart';
import 'player_controller.dart';
import 'user_api_debug_controller.dart';

final lyricProvider =
    FutureProvider.family<LyricPayload?, Track>((ref, track) async {
  ref.watch(userApiDebugProvider.select((state) => state.activeSourceId));
  ref.watch(userApiDebugProvider.select((state) => state.runtimeRevision));
  final local = await LocalLyricLoader().load(track);
  if (local != null || track.sourceKind != TrackSourceKind.online) return local;
  final kuwo = await KuwoLyricService().resolve(track);
  if (kuwo != null) return kuwo;
  return ref.watch(userApiRunnerProvider).resolveLyric(track);
});
