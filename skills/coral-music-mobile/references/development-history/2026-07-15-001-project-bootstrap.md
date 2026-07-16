# P0-01 Flutter 三端工程与应用壳补录

- 任务编号：P0-01
- 阶段：Phase 0
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-15 前
- 完成时间：2026-07-15

## 目标、范围与依赖

创建 iOS、Android、鸿蒙 Flutter 工程，统一包名 `com.coral.music.mobile`，提供九个入口、默认排行榜、自适应导航和迷你播放栏占位。依赖为已安装的 OpenHarmony Flutter 发行版；不包含真实业务、音频和持久化。

## 桌面端基线与方案

对照 `src/renderer-react/app/routeConfig.tsx` 的九条路由和 `UiStore.activeRoute = leaderboard`。移动端用底部导航、更多页及宽屏 `NavigationRail` 实现等价入口。

## 实际改动与验证

- 建立 `ios/`、`android/`、`ohos/`、`lib/main.dart` 和 `test/app_shell_test.dart`。
- `flutter analyze`、`flutter test`、Android Debug APK 和 unsigned HAP 已在前序工作中通过。
- 未进行三端真机验证。

## 风险与后续

当前应用壳仍为单文件占位实现，由 `B1-02`、`B1-06` 接续重构。

