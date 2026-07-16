import '../../../core/app_failure.dart';
import '../../../domain/music.dart';
import 'user_api_runner.dart';

final class PlaybackResolver {
  PlaybackResolver(this._userApiRunner);

  final UserApiRunner _userApiRunner;

  Future<Uri> resolve(Track track, {AudioQuality? quality}) {
    if (track.sourceKind != TrackSourceKind.online) {
      throw const AppFailure(
        code: AppFailureCode.invalidData,
        message: '该来源尚未接入播放解析',
      );
    }
    final resolvedQuality = quality ??
        (track.availableQualities.isEmpty
            ? AudioQuality.standard128k
            : track.availableQualities.last);
    return _userApiRunner.resolveMusicUrl(track, resolvedQuality);
  }
}
