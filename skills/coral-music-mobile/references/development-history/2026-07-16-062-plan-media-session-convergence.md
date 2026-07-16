# 计划修订：系统媒体会话收敛

- 阶段：Batch 4 / Phase 3
- 状态：DONE（计划修订已写入）
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：2026-07-16

## 目标、范围与依赖

将历史上的 Android `MediaSessionBridge` 收敛为 `AudioEngine` 内的 `audio_service` 处理器，保持一套播放状态与系统命令通道。

范围：删除不再发布快照的 Flutter/Android MethodChannel 桥接，更新架构和 Phase 3 计划。依赖 B4-22 已通过的 `audio_service` 依赖图与 `AudioEngineCommand` 队列路由。

不做：锁屏、耳机、后台切换或进程回收的真机验收；这些仍在 B4-22 内执行。

## 桌面端对照与决策

桌面端系统媒体能力只有一个当前播放状态来源。移动端同时保留两个 Android 会话会造成空闲抢占和状态漂移，故以 `audio_service` 的跨平台处理器为唯一实现；业务层仍只依赖 `AudioEngine`。

## 修改、验证与后续

- 修改：移除旧 `MediaSessionBridge` Dart/Kotlin 文件及其 Provider、控制器分支、测试；系统上一首/下一首仍由 `AudioEngine.commands` 接入现有播放队列。
- 文档：更新 `architecture.md`、`development-plan.md` 和 B4-18 历史，将 B4-18 标为 `SUPERSEDED`。
- 验证通过：`flutter test test/player_controller_test.dart -r compact`（8 项）、`flutter analyze --no-fatal-infos`、`flutter build apk --debug`、`quick_validate.py skills/coral-music-mobile` 与 `git diff --check`。构建输出为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 关联：B4-18、B4-22、P3-01、P3-07；恢复入口为 B4-22 的 Android 真机锁屏/耳机/后台验收。
