# UI-02 迷你播放栏与底部导航布局修复

- 阶段：高保真 UI 重构 / 应用壳修复
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-16 18:01 CST
- 完成时间：2026-07-16 18:05 CST

## 目标、范围与依赖

修复 Android 真机中迷你播放状态条被底部 Navbar 覆盖的问题，使其始终位于导航栏上方并保留现有安全区、点击进入播放详情和播放控制行为。

依赖 UI-01 的 `AppShell` 与 `MiniPlayer`。不调整导航项目、播放器状态流、播放栏视觉样式或页面内滚动区。

## 原因、桌面基线与实施方案

- 移动端设计稿要求迷你播放栏位于内容和底部导航之间；桌面端没有同一底栏叠放结构，因此以移动端等价布局为准。
- 当前 `AppShell` 设置了 `Scaffold.extendBody: true`，导致 body 延伸到半透明 `NavigationBar` 后方。`Column` 尾部的 `MiniPlayer` 因此与 Navbar 发生几何重叠。
- 采用 Flutter 原生布局边界：关闭 `extendBody`。Scaffold 将 body 自动约束在 `bottomNavigationBar` 之上，无需硬编码导航栏高度或设备底部 inset。

## 验收计划与恢复入口

- Widget：`MiniPlayer` 的 bottom 坐标不进入 `NavigationBar` 的顶部区域。
- Android 真机：已连接 Samsung SM-N986U / Android 13，播放中检查迷你播放栏与 Navbar 之间无重叠，且仍可进入播放详情。
- 修改入口：`lib/app/app_shell.dart`；关联 UI-01、功能矩阵“主导航”“播放详情”。

## 实际修改、验证与决策

- 修改：`lib/app/app_shell.dart` 将 `extendBody` 改为 `false`；`test/app_shell_test.dart` 新增迷你播放栏底部不超过 `NavigationBar` 顶部的几何回归。
- `dart format`、`dart analyze lib/app/app_shell.dart test/app_shell_test.dart` 与 `git diff --check` 通过；新增的 `flutter test test/app_shell_test.dart --plain-name 'keeps the mini player above the bottom navigation' -r expanded` 通过。完整旧 `app_shell_test.dart` 还包含多项与新版首页文本重复/异步路由初始化不兼容的既有选择器，后续应作为测试维护任务单独修复，不能误记为本布局断言失败。
- Android Debug APK 构建成功并覆盖安装到 Samsung SM-N986U / Android 13。UI Automator 实测：迷你播放栏 bounds 为 `[34,1812][1046,1977]`，Navbar 首项 bounds 为 `[0,2001][270,2123]`，两者相隔 24px；播放栏不再被导航栏遮挡。
- 选择关闭 `extendBody` 而非手工添加底部高度：该方法会随系统导航栏、Material NavigationBar 高度和设备安全区变化自动正确布局，且没有引入额外状态或平台分支。
