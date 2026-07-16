# B4-18 Android MediaSession 前台媒体控制

- 阶段：Batch 4 / Phase 3
- 状态：SUPERSEDED（已收敛到 B4-22）
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

把当前 Flutter 播放状态发布至 Android `MediaSession`，接收系统播放、暂停、上一首、下一首、停止指令并路由回已有 `PlayerController`。

不做：前台媒体服务、进程被杀后的后台持续播放、通知自定义布局、iOS/HarmonyOS MediaSession 实现和耳机真机验收。

## 平台方案

- 使用 Android 原生 `android.media.session.MediaSession`，不引入尚未验证鸿蒙兼容性的 `audio_service`。
- Flutter 侧单一 MethodChannel 只交换可序列化的曲目、位置、时长、状态与命令；业务代码不访问 Android SDK。

## 验收

- 播放中系统媒体会话显示标题/歌手和可用操作；系统命令能驱动现有播放器控制。
- Android Debug 可构建；锁屏、耳机及后台持续播放必须在真机补录后才可完成。

## 当前进度

- 已实现 Flutter `MediaSessionBridge` 与 Android 原生 `MediaSession`：发布曲目/位置/状态，接收播放、暂停、上下首、停止命令。
- `PlayerController` 复用已有 toggle、队列和 stop 路径处理系统命令；新增聚焦测试覆盖暂停指令路由。
- 已通过 `flutter test`、`flutter analyze --no-fatal-infos`、skill 格式校验及 Android Debug APK 构建。
- 真机：SM-N986U / Android 13 已覆盖安装 Debug APK 并启动；`MediaSessionService` 日志确认媒体按键会话切换为 `com.coral.music.mobile/CoralMusic`，系统 FaceWidget 收到对应 session token。
- 根据真机日志调整：会话不再在应用启动时激活，只有 Flutter 发布实际曲目状态后才激活；清理时主动撤销激活状态，避免空闲应用抢占媒体按键。
- 回归：重新构建、覆盖安装并强制停止/启动应用后，`dumpsys media_session` 不再出现 `com.coral.music.mobile/CoralMusic` 活动会话，符合空闲不抢占要求。
- B4-22 的 `audio_service` 已成为实际的跨平台系统媒体运行时；旧桥接停止接收播放快照，保留它只会创建另一条无效的 Android 会话路径。已删除 Flutter/Android MethodChannel 桥接及其聚焦测试，系统上一首/下一首统一由 `AudioEngine.commands` 路由队列。

## 风险与后续

- 旧桥接不再继续验收；完整后台服务、锁屏和耳机命令转由 B4-22 追踪。Android 真实播放后的系统媒体控制、iOS/鸿蒙平台实现与验收仍待完成。
