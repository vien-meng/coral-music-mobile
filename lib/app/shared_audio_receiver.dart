import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sharedAudioPathsProvider = StateProvider<List<String>>((_) => const []);

final class SharedAudioReceiver {
  static const _channel = MethodChannel('coral_music/shared_audio');

  static Future<void> install(WidgetRef ref) async {
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'shared') {
          _setPaths(ref, call.arguments);
        }
      });
      _setPaths(ref, await _channel.invokeMethod<Object?>('consume'));
    } on MissingPluginException {
      // Platform support is added independently; no shared item is pending.
    }
  }

  static void _setPaths(WidgetRef ref, Object? raw) {
    final paths = (raw as List?)
            ?.whereType<String>()
            .where((path) => path.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    if (paths.isNotEmpty) {
      ref.read(sharedAudioPathsProvider.notifier).state = paths;
    }
  }
}
