# B6-16 主题模式持久化

- 阶段：Batch 6 / Phase 6
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：2026-07-20

## 目标、范围与依赖

将当前系统主题行为扩展为可选择并跨重启保存的“跟随系统 / 浅色 / 深色”。主题更改必须只更新 Material 主题，不能重建路由或清空播放/导航状态。

复用已安装的 `flutter_secure_storage` 保存一个非敏感偏好。不会加入调色盘、无真实翻译资源的语言开关，或影响播放/下载数据。

## 实施记录

- 2026-07-20：开始实现主题偏好控制器和设置页入口。
- 新增 `ThemeModeController`：复用系统安全存储保存 `system/light/dark`，存储不可用时安全回落到跟随系统；用户刚选择的模式不会被异步恢复结果覆盖。
- 设置页新增“主题外观”，可以即时切换并跨启动恢复。
- `MaterialApp.router` 改为持有单一 `GoRouter` 实例，主题更新只重建主题，不重新创建导航树。
- 所有实际模块边框从固定 `CoralPalette.border` 改为 `ColorScheme.outlineVariant`；浅色沿用珊瑚描边，深色自动使用深色主题描边。
- 实际修改：`theme_mode_controller.dart`、`app.dart`、`app_theme.dart` 使用方、设置页与多处模块页面、`test/app_theme_test.dart`。
- 验证：`dart format`、`flutter analyze`、`flutter test test/app_theme_test.dart test/ignored_keyword_test.dart test/library_backup_codec_test.dart`、`git diff --check` 通过。

## 已知限制与下一步

- 没有加入语言切换，因为当前没有完整翻译资源；避免显示无法生效的开关。
- 下一步：继续发布前工程能力，优先处理深链和系统分享入口。
