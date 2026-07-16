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
  final _name = TextEditingController();
  final _script = TextEditingController();
  final _scriptUrl = TextEditingController();
  final _url = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _script.dispose();
    _scriptUrl.dispose();
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
        const Text('音源管理',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('脚本只在当前会话保留；仅允许受限 HTTPS 取链，不会写入本地数据库。'),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: '音源名称（可选）'),
        ),
        const SizedBox(height: 8),
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
              : () => ref
                  .read(userApiDebugProvider.notifier)
                  .importScript(_name.text, _script.text),
          child: Text(userApi.isLoading ? '正在验证' : '导入并启用音源'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _scriptUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: '或输入 HTTPS 脚本地址'),
        ),
        TextButton(
          onPressed: userApi.isLoading
              ? null
              : () => ref
                  .read(userApiDebugProvider.notifier)
                  .importUrl(_name.text, _scriptUrl.text),
          child: const Text('从地址导入并启用'),
        ),
        if (userApi.sources.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('本次会话中的音源', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final source in userApi.sources)
            Card(
              child: RadioListTile<String>(
                value: source.id,
                groupValue: userApi.activeSourceId,
                onChanged: userApi.isLoading
                    ? null
                    : (id) => id == null
                        ? null
                        : ref.read(userApiDebugProvider.notifier).activate(id),
                title: Text(source.name),
                subtitle: Text(_capabilities(source)),
                secondary: IconButton(
                  tooltip: '移除音源',
                  onPressed: userApi.isLoading
                      ? null
                      : () => ref
                          .read(userApiDebugProvider.notifier)
                          .remove(source.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
        ],
        if (userApi.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(userApi.error!.message),
          ),
        const Divider(height: 40),
        const Text('播放调试', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
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
        if (player.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(player.error!.message),
          ),
      ],
    );
  }
}

String _capabilities(UserApiSource source) {
  final values = [
    if (source.musicUrlSources.isNotEmpty)
      '取链：${source.musicUrlSources.join('、')}',
    if (source.lyricSources.isNotEmpty) '歌词：${source.lyricSources.join('、')}',
  ];
  return values.isEmpty ? '未声明可用能力' : values.join(' · ');
}
