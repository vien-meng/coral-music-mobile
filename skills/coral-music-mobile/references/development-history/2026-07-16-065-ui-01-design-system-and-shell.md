# UI-01 设计系统与应用壳

- 阶段：高保真 UI 重构 / 第一任务
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标、范围与依赖

建立与设计稿一致的共享色彩、排版、圆角、卡片和导航外壳，并重构迷你播放栏。依赖现有 `AppShell`、`MiniPlayer`、`go_router`、`PlayerController`，不改变它们的数据流。

包含：浅色主题、系统深色等价、背景渐变、手机底栏、宽屏 Rail、迷你播放器、可复用封面占位样式。

不包含：首页内容、搜索结果、播放器详情和设置表单的逐页布局；它们由后续 UI-02 至 UI-05 处理。

## 设计与平台差异

- 采用 Material 3 现有能力，无新依赖和代码生成；视觉令牌置于 `app_theme.dart`，避免页面复制色值。
- 手机底栏按稿显示首页、发现、播放和我的；原有九个入口保持路由不变，非主入口收纳在“我的/更多”路径。
- 播放 tab 直接进入 `/player`；没有曲目时仍展示现有空状态，不能伪造播放状态。
- 封面网络失败使用渐变音乐符号占位，不引入设计稿的版权图像。

## 实施与验证计划

1. 写入主题扩展与共享圆角/渐变样式。
2. 改写应用壳、底栏、宽屏 Rail 与 MiniPlayer。
3. 更新现有 widget test 的稳定语义，执行格式、分析和聚焦测试。
4. 在 Android 真机安装后检查窄屏导航、迷你播放器和播放详情入口。

## 当前修改与恢复入口

- 已修改：`lib/app/app_theme.dart` 集中定义薄荷、天空蓝、薰衣草、粉色和紫色播放色，并统一卡片、输入框、底栏与深色等价主题；`lib/app/app_shell.dart` 改为稿件的四项主导航和渐变页面壳，宽屏保留 Rail；`lib/features/player/view/mini_player.dart` 改为圆角半透明卡片、封面占位、圆形播放按钮和细进度条；`test/app_shell_test.dart` 将旧的“更多/搜索”导航断言改为“我的/发现”。
- 重要决策：播放导航始终进入真实 `/player`，空队列只展示既有“未在播放”状态；非主入口仍由“我的”进入，未删除九个功能路由。
- 格式化已使用项目的 Harmony Flutter SDK 自带 Dart 完成。该 SDK 执行 `flutter analyze` 时因环境未设置 `HOS_SDK_HOME` 直接报 `No Hmos SDK found`，未进入代码分析；因此本任务保留 `DOING`，不以未运行的检查标记完成。
- 补充验证：同一 SDK 的 `dart analyze lib test` 已在 UI-01 至 UI-05 当前合并状态下通过（`No issues found!`）；Flutter widget 测试与 Android 真机视觉回归仍待环境恢复后执行。
- 恢复入口：环境恢复后执行 `flutter analyze --no-fatal-infos` 和 `flutter test test/app_shell_test.dart test/mini_player_test.dart -r compact`；UI-02 可以独立继续页面表现层开发。

## 关联

- 计划：`2026-07-16-064-plan-high-fidelity-ui.md`。
- 功能矩阵：主导航、播放详情与歌词呈现。
