import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_back_navigation.dart';
import '../../../app/app_theme.dart';
import '../../../app/theme_mode_controller.dart';
import '../../../domain/music.dart';
import '../../player/state/default_quality_controller.dart';
import '../../download/state/download_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final quality = ref.watch(defaultPlaybackQualityProvider);
    final downloadDirectory = ref.watch(downloadDirectoryProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 24),
      children: [
        Row(children: [
          const AppBackButton(),
          Text('设置',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
        ]),
        const SizedBox(height: 8),
        Text('只显示当前可实际生效的管理项。', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 18),
        _SettingsGroup(title: '网盘资源', children: [
          _SettingsItem(
            icon: Icons.cloud_outlined,
            title: '网盘资源',
            subtitle: '连接个人 WebDAV 音乐目录',
            onTap: () => context.push('/webdav'),
          ),
        ]),
        const SizedBox(height: 16),
        _SettingsGroup(title: '本机数据', children: [
          _SettingsItem(
            icon: Icons.high_quality_outlined,
            title: '默认播放音质',
            subtitle: _qualityLabel(quality),
            onTap: () async {
              final selected = await showModalBottomSheet<AudioQuality>(
                context: context,
                builder: (context) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final option in AudioQuality.values)
                        ListTile(
                          title: Text(_qualityLabel(option)),
                          trailing: option == quality
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(context, option),
                        ),
                    ],
                  ),
                ),
              );
              if (selected != null) {
                await ref
                    .read(defaultPlaybackQualityProvider.notifier)
                    .setQuality(selected);
              }
            },
          ),
          _SettingsItem(
            icon: Icons.palette_outlined,
            title: '主题外观',
            subtitle: _themeLabel(themeMode),
            onTap: () async {
              final selected = await showModalBottomSheet<ThemeMode>(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final mode in ThemeMode.values)
                      ListTile(
                        title: Text(_themeLabel(mode)),
                        trailing:
                            mode == themeMode ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.pop(context, mode),
                      ),
                  ]),
                ),
              );
              if (selected != null) {
                await ref.read(appThemeModeProvider.notifier).setMode(selected);
              }
            },
          ),
          _SettingsItem(
            icon: Icons.download_outlined,
            title: '下载管理',
            subtitle: '查看、暂停、继续或移除离线歌曲',
            onTap: () => context.push('/download'),
          ),
          _SettingsItem(
            icon: Icons.folder_outlined,
            title: '下载目录',
            subtitle: Platform.isIOS
                ? '应用下载目录（可读写）'
                : downloadDirectory ?? '默认应用下载目录',
            onTap: () =>
                _pickDownloadDirectory(context, ref, downloadDirectory),
          ),
          _SettingsItem(
            icon: Icons.library_music_outlined,
            title: '我的列表',
            subtitle: '管理本地导入、收藏和播放列表',
            onTap: () => context.push('/list'),
          ),
          _SettingsItem(
            icon: Icons.block_outlined,
            title: '不感兴趣',
            subtitle: '管理播放全部时自动跳过的歌曲',
            onTap: () => context.push('/setting/ignored'),
          ),
          _SettingsItem(
            icon: Icons.backup_outlined,
            title: '资料备份',
            subtitle: '导出或合并恢复本地列表、收藏和规则',
            onTap: () => context.push('/setting/backup'),
          ),
        ]),
      ],
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '跟随系统',
        ThemeMode.light => '浅色模式',
        ThemeMode.dark => '深色模式',
      };

  String _qualityLabel(AudioQuality quality) => switch (quality) {
        AudioQuality.master => '臻品母带',
        AudioQuality.atmosPlus => '臻品全景声',
        AudioQuality.atmos => '全景声',
        AudioQuality.hires => 'Hi-Res',
        AudioQuality.flac24bit => 'Hi-Res 24bit',
        AudioQuality.flac => 'SQ（无损 FLAC）',
        AudioQuality.high320k => 'HQ（320k）',
        AudioQuality.high192k => '192k',
        AudioQuality.standard128k => '128k',
      };

  Future<void> _pickDownloadDirectory(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    if (Platform.isIOS) {
      final saved = await ref
          .read(downloadDirectoryProvider.notifier)
          .useApplicationDirectory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved ? '已使用 iOS 应用下载目录。' : '无法创建应用下载目录。'),
        ));
      }
      return;
    }
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择下载目录',
      initialDirectory: current,
    );
    if (directory == null || !context.mounted) return;
    final saved = await ref
        .read(downloadDirectoryProvider.notifier)
        .setDirectory(directory);
    if (context.mounted && !saved) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('该目录不可写，请选择其他目录。')));
    }
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(children: children),
          ),
        ],
      );
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: CoralPalette.brand),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_outlined),
        onTap: onTap,
      );
}
