# UI-10 主题色模块描边

- 阶段：UI 优化 / Batch 6
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：2026-07-20

## 目标、范围与依赖

让卡片、列表和输入框共用的模块边框从当前主题主色推导，而不是使用固定灰色或固定深色值。描边保持低饱和、1px，避免暖白界面变成厚重色块。

依赖既有的 `coralTheme` 和 `ColorScheme.outlineVariant`；不新增主题库、不改变按钮或页面布局。

## 实施记录

- 2026-07-20：开始检查所有模块边框，确认业务页面已经统一读取 `ColorScheme.outlineVariant`，问题集中在主题层的静态深色描边值。接下来只在主题层修正一次，所有调用方自动随之更新。
- 2026-07-20：`outlineVariant` 改为主题 `primary` 与 `surface` 的低透明度混合；浅色是克制的珊瑚描边，深色也保留对应暖色倾向而非冷灰。页面调用方无需改动。
- 2026-07-20：复查发现应用壳分隔线、品牌标记、默认描边按钮与播放页小控件仍自行从中性 `onSurface`/`dividerColor` 取色；全部改为同一 `outlineVariant`，品牌图标改为 `primary`，因此浅色、深色切换时不再出现灰色孤岛。
- 验证：`dart format`、`flutter test test/app_theme_test.dart` 通过；首次 `flutter analyze` 仅报测试使用已弃用的颜色通道，已改为 `.r/.b`，待复验。

## 验收与下一步

- `dart format`、`flutter test test/app_theme_test.dart`、`flutter analyze` 与 `git diff --check` 均已通过；Debug APK 已成功安装至 Samsung Android 13 真机 `R5CR70B7SMA`，等待人工确认视觉效果。
- 关联：`UI-09`、`B6-16`、`P6-04`。
