import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
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
    final controller = ref.read(userApiDebugProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Text('导入音源', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          '通过 HTTPS 地址导入受限音源脚本。脚本只在本次会话保留，不会写入本地数据库。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CoralPalette.mint.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.link_rounded,
                          color: CoralPalette.mint),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('从 URL 导入',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _scriptUrl,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _importUrl(controller, userApi.isLoading),
                  decoration: const InputDecoration(
                    hintText: '粘贴 HTTPS 音源地址',
                    prefixIcon: Icon(Icons.language_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: userApi.isLoading
                        ? null
                        : () => _importUrl(controller, false),
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: Text(userApi.isLoading ? '正在验证音源…' : '导入并启用'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (userApi.error != null) ...[
          const SizedBox(height: 12),
          _InlineError(message: userApi.error!.message),
        ],
        if (userApi.sources.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('已导入的音源', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final source in userApi.sources) ...[
            _SourceDetailsCard(
              source: source,
              active: source.id == userApi.activeSourceId,
              loading: userApi.isLoading,
              onActivate: () => controller.activate(source.id),
              onRefresh: source.id == userApi.activeSourceId &&
                      source.originUrl != null
                  ? () => controller.refresh(source.id)
                  : null,
              onRemove: () => controller.remove(source.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('高级导入'),
            subtitle: const Text('仅在 URL 导入不可用时粘贴原始脚本'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '自定义名称（可选）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _script,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'User API 脚本',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: userApi.isLoading
                      ? null
                      : () => controller.importScript(_name.text, _script.text),
                  icon: const Icon(Icons.code_rounded),
                  label: const Text('验证并启用粘贴脚本'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('播放调试'),
            subtitle: const Text('仅用于开发验证，不影响已导入音源'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'HTTPS 音频地址'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(playerProvider.notifier).playDebugUrl(_url.text),
                  child: const Text('播放调试地址'),
                ),
              ),
              if (player.error != null) ...[
                const SizedBox(height: 10),
                _InlineError(message: player.error!.message),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _importUrl(UserApiDebugController controller, bool loading) {
    if (loading) return;
    controller.importUrl('', _scriptUrl.text);
  }
}

class _SourceDetailsCard extends StatelessWidget {
  const _SourceDetailsCard({
    required this.source,
    required this.active,
    required this.loading,
    required this.onActivate,
    required this.onRefresh,
    required this.onRemove,
  });

  final UserApiSource source;
  final bool active;
  final bool loading;
  final VoidCallback onActivate;
  final VoidCallback? onRefresh;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = [
      if (source.info.version != null) ('版本', source.info.version!),
      if (source.info.author != null) ('作者', source.info.author!),
      if (source.info.homepage != null) ('主页', source.info.homepage!),
    ];
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: loading || active ? null : onActivate,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (active ? CoralPalette.player : CoralPalette.sky)
                          .withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: active ? CoralPalette.player : scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(source.name,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (active)
                    Chip(
                      label: const Text('已启用'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: CoralPalette.mint.withValues(alpha: .16),
                    ),
                  if (onRefresh != null)
                    IconButton(
                      tooltip: '从原地址刷新音源',
                      onPressed: loading ? null : onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  IconButton(
                    tooltip: '移除音源',
                    onPressed: loading ? null : onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              if (source.info.description != null) ...[
                const SizedBox(height: 12),
                Text(source.info.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final detail in details)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${detail.$1}：${detail.$2}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                  ),
              ],
              if (source.originUrl != null) ...[
                const SizedBox(height: 8),
                Text(
                  source.originUrl.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                      ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in _capabilities(source))
                    Chip(
                      label: Text(label),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

List<String> _capabilities(UserApiSource source) {
  final keys = {...source.musicUrlSources, ...source.lyricSources}.toList()
    ..sort();
  return [
    for (final key in keys)
      '${_sourceName(key)} · ${[
        if (source.musicUrlSources.contains(key)) '播放',
        if (source.lyricSources.contains(key)) '歌词',
      ].join(' / ')}',
  ];
}

String _sourceName(String source) => switch (source) {
      'kw' => '酷我音乐',
      'kg' => '酷狗音乐',
      'tx' => 'QQ 音乐',
      'wy' => '网易云音乐',
      'mg' => '咪咕音乐',
      'local' => '本地音乐',
      _ => source.toUpperCase(),
    };
