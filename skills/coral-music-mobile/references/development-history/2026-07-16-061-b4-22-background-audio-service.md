# B4-22 三端后台播放运行时与系统媒体服务

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 2026-07-16 进行中：音频中断边界

- 核查当前已使用的 `just_audio 0.10.6`：其默认 `handleInterruptions` 已订阅 `audio_session` 的系统中断与耳机拔出事件，并将暂停状态回传至现有快照流。重复订阅会产生二次暂停/恢复竞态，因此不另写平台逻辑。
- 继续采用默认的中断结束恢复策略；来电、导航、耳机拔出及多设备焦点竞争仍须三端真机验收，不能用源码推断替代。

## 2026-07-16 进行中：收敛旧媒体会话

- `audio_service` 已是唯一的系统媒体处理器：它发布元数据和播放状态，并把系统上一首/下一首命令送入 `AudioEngine.commands`。旧的 Android `MediaSessionBridge` 已停止接收快照却仍会被实例化，属于无效的第二条会话路径。
- 本次将移除旧 MethodChannel 桥接及其 Android `MediaSession`，`PlayerController` 只监听 `AudioEngineCommand`，避免重复注册、空闲抢占或两套状态不一致。

## 目标、范围与依赖

将现有 `JustAudioEngine` 从仅存活于 Flutter Activity 的播放器升级为可由系统前台媒体服务托管的运行时，使 Android、iOS 和鸿蒙能够共享后台播放、锁屏媒体信息与耳机控制的业务路径。

依赖：B4-01 最小播放、B4-18 Android `MediaSession`。不做下载后台任务、跨进程队列持久化、iOS/鸿蒙真机验收或应用商店发布配置。

## 方案与平台差异

- 目标依赖是 `audio_service` 配合现有 `just_audio`；它提供三端后台媒体服务边界，业务层仍只调用 `AudioEngine`。
- OpenHarmony 官方适配仓库提供 `fluttertpc_audio_service`，但当前 fork 绑定 `audio_session 0.1.21`，与现有 `just_audio 0.10.6` 的 `>=0.1.24` 要求不兼容；不能为接入后台服务降级播放器或破坏现有鸿蒙实现。
- 在依赖图与最小运行时通过前，保留已有 Android `MediaSessionBridge` 作为临时按键/元数据桥接；不把它误标记为完整后台播放。

## 当前进度与恢复入口

- 已确认现有 Activity 级 MediaSession 无法承担进程回收后的播放；`just_audio` 的本地文档也将后台播放指向 `audio_service`。
- `flutter pub add audio_service:^0.18.15` 复现 Git/hosted `sqflite` source 冲突；采用 OpenHarmony fork 后继续复现其旧 `audio_session 0.1.21` 与当前 `just_audio 0.10.6` 的版本冲突。
- 上游 `audio_service 0.18.12` 虽可避开缓存依赖，但它仅支持 `audio_session 0.1.x`；项目的 `just_audio_harmonyos` 要求 `audio_session 0.2.2`，仍无法组成三端依赖图。
- `audio_service 0.18.15` 仍只支持 `audio_session 0.1.x`；pub 解析器明确建议升级到 `0.18.19+` 才能与当前 `audio_session 0.2.x` 组合。现保持 Git `sqflite` override 并验证该版本；解析失败即恢复依赖图，不以破坏鸿蒙构建换取 Android 后台服务。
- `audio_service ^0.18.19` 与现有 `just_audio`、`just_audio_harmonyos` 及 Git `sqflite` 的依赖解析通过；锁文件明确记录 Git `sqflite` override。
- `JustAudioEngine` 已改为把 `just_audio` 实例放进 `AudioService` 的统一处理器；处理器发布媒体标题、艺术家、封面、时长、播放状态与 seek 状态。不存在 OHOS 原生插件时只捕获 `MissingPluginException` 并回退到同一 `just_audio` 处理器。
- Android 已声明前台媒体服务、媒体按钮接收器、必要权限，`MainActivity` 改为继承 `AudioServiceActivity`；iOS 已声明 `UIBackgroundModes/audio`。
- 未声明尚未实现的系统上一首/下一首控件，避免给系统暴露无效操作；应用内队列切歌仍保持现有实现。
- 后续补齐：`AudioEngineCommand` 将 `audio_service` 的上一首/下一首回调路由到既有 `PlaybackQueueController`；移除了播放快照到旧 Android `MediaSessionBridge` 的重复发布，避免同一播放产生两份系统媒体会话。
- `AudioSessionConfiguration.music()` 在后台服务创建后应用；现有 `just_audio` 保持默认中断处理，因此电话、导航和耳机拔出事件走统一播放器暂停/恢复逻辑。
- 真机安装/启动后，Android 13（SM-N986U）日志显示空闲应用已成为 media button session；这会抢占其他播放器按键。撤回 `main()` 预初始化，恢复为首次创建播放器时才初始化 `AudioService`，以“正在或已开始播放”优先于空闲占位。
- 继续追踪发现 `audioEngineProvider` 会在应用壳创建时实例化，因此改为 `JustAudioEngine.load()` 首次调用时才创建 handler 并订阅其状态/命令流；空闲 UI 不再触发媒体服务注册。
- 冷启动摘要仍显示 `com.coral.music.mobile/media-session`，来源是 `AudioServiceActivity` 自身而非 Dart handler。`MainActivity` 恢复 `FlutterActivity`，避免 Activity 空闲时注册媒体按钮会话；后台服务仍由首次 `AudioService.init` 建立，真实后台恢复行为留待播放态真机验收。
- 验证：重新构建、安装、`am force-stop`、冷启动后执行 `dumpsys media_session`，不再出现 `com.coral.music.mobile/media-session` 活跃会话；Android 13 / SM-N986U。此前的 `Last MediaButtonReceiver` 是系统历史记录，不作为活跃会话证据。
- 实际修改：`pubspec.yaml`、`pubspec.lock`、`lib/features/player/data/audio_engine.dart`、`android/app/src/main/AndroidManifest.xml`、`android/app/src/main/kotlin/com/coral/music/mobile/MainActivity.kt`、`ios/Runner/Info.plist`，以及计划与功能矩阵。

## 验收与风险

- 自动验证：`flutter pub get`、`dart format`、`flutter analyze --no-fatal-infos`、`flutter build apk --debug` 已通过。
- 回归：`flutter test test/player_controller_test.dart test/lyric_timeline_test.dart -r compact` 与 `quick_validate.py skills/coral-music-mobile` 均通过。
- 新增回归：`routes background next commands through the playback queue`，验证后台下一首走统一队列而非在音频处理器中复制队列。
- 媒体会话收敛回归：删除旧 Android MethodChannel 会话后，`flutter test test/player_controller_test.dart -r compact`、`flutter analyze --no-fatal-infos`、`flutter build apk --debug`、skill 校验和 `git diff --check` 均通过；锁屏、耳机和后台真机验收仍未完成。
- 真机验收：后台切换、锁屏/通知媒体卡、耳机播放暂停、进程回收策略；当前均未完成。
- 风险：鸿蒙适配仓库没有独立许可证声明，正式发布前需按上游 `audio_service` 许可证审计；动态音源 URL 的有效期也会影响长时间后台播放。
