import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/player_controller.dart';
import '../state/user_api_debug_controller.dart';

class UserApiDebugPage extends ConsumerStatefulWidget {
  const UserApiDebugPage({super.key});

  @override
  ConsumerState<UserApiDebugPage> createState() => _UserApiDebugPageState();
}

class _UserApiDebugPageState extends ConsumerState<UserApiDebugPage> {
  final _script = TextEditingController();
  final _url = TextEditingController();

  @override
  void dispose() {
    _script.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userApi = ref.watch(userApiDebugProvider);
    final player = ref.watch(playerProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('播放调试',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('仅接受 HTTPS 地址；脚本只在 Android 调试运行时临时启用，不会保存。'),
        const SizedBox(height: 16),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'HTTPS 音频地址'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () =>
              ref.read(playerProvider.notifier).playDebugUrl(_url.text),
          child: const Text('播放调试地址'),
        ),
        const Divider(height: 40),
        TextField(
          controller: _script,
          minLines: 8,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: 'User API 脚本',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: userApi.isLoading
              ? null
              : () =>
                  ref.read(userApiDebugProvider.notifier).load(_script.text),
          child: Text(userApi.isLoading ? '正在验证' : '启用临时调试音源'),
        ),
        if (userApi.musicUrlSources.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('已支持取链来源：${userApi.musicUrlSources.join('、')}'),
          ),
        if (userApi.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(userApi.error!.message),
          ),
        if (player.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(player.error!.message),
          ),
      ],
    );
  }
}
