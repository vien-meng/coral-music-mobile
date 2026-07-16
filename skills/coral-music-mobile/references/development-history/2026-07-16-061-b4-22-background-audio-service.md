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

## 2026-07-16 真机回归：空闲媒体会话仍存在

- 已在 SM-N986U / Android 13 覆盖安装最新 Debug APK，执行 `am force-stop` 后冷启动并读取 `dumpsys media_session`。
- 实际结果：系统仍创建了 `com.coral.music.mobile/media-session`，状态为 `NONE`、`active=false`，但被 Samsung 系统列为 `Media button session`。这与“空闲不注册会话”的旧记录矛盾，不能再将其作为通过项。
- 日志显示会话在 Activity 启动后产生；当前 Flutter `JustAudioEngine` 尚未调用 `AudioService.init`，因此需要在 audio_service Android 服务/receiver 生命周期层继续定位。为避免破坏已接入的后台媒体能力，本次不删除官方要求的 service/receiver 声明。
- 验证命令与 APK：`adb install -r build/app/outputs/flutter-apk/app-debug.apk`、`adb shell am force-stop com.coral.music.mobile`、`adb shell monkey -p com.coral.music.mobile 1`、`adb shell dumpsys media_session`。任务保持 `DOING`。

## 2026-07-16 修复计划：按播放状态启用 receiver

- Android manifest 将 `MediaButtonReceiver` 默认设为 disabled。首次真实音频加载前由同一后台媒体通道启用它，处理器 `stop` 后再次禁用；这样官方 `audio_service` 在播放/暂停期间的通知、耳机和后台路径不变，空闲冷启动不会暴露 receiver。
- 不在 `pause` 时禁用：暂停后的通知和恢复按键仍是播放器的必要行为。该方案只影响 Android，并将在同一 SM-N986U 真机重新执行冷启动和播放态检查。
- 第一次回归表明 disabled receiver 仍不足：`dumpsys` 的会话 receiver 已为 null，但 `AudioService` 自身仍在冷启动后创建 session。因此将服务本身也改为默认 disabled，并和 receiver 在首个真实 load 前一起启用；不把该失败回归标为通过。

## 2026-07-16 真机回归：空闲会话已消除

- 实际修改：`AudioService` 与 `MediaButtonReceiver` 都默认 disabled；`_createHandler` 在 `AudioService.init` 前通过 `coral_music/background_media` 启用二者，处理器 `stop` 后禁用。Android 原生只切换两个官方组件，不新增播放逻辑。
- 验证通过：`dart format`、`flutter analyze --no-fatal-infos`、`flutter build apk --debug`；SM-N986U / Android 13 覆盖安装后执行冷启动检查，`dumpsys media_session` 显示 `Media button session is null`、`Sessions Stack - have 0 sessions`。
- 未完成：第一次真实播放后服务/receiver 是否成功启用、暂停/锁屏/耳机/后台 stop 后是否再次清理，仍需在解锁设备和可用 HTTPS 音源下验收；B4-22 继续保持 `DOING`。
- 失败清理：若 `AudioService.init` 或 audio session 配置失败，Dart 会立即重新禁用 Android service/receiver 后再回退或抛出，避免失败初始化遗留下一次冷启动的空闲会话。
- 验证通过：`dart format lib/features/player/data/audio_engine.dart`、`flutter analyze --no-fatal-infos`、skill 校验与 `git diff --check`。

## 2026-07-16 真机回归：首次播放失败定位

- 在同一设备的“播放调试”页输入公开 HTTPS MP3 地址后，系统记录到本应用音频输出，但 `dumpsys media_session` 仍无活动会话，界面进入“调试音频加载失败”。组件状态确认 `AudioService` 与 `MediaButtonReceiver` 已被按需启用，因此问题发生在服务初始化或首次加载链路，不能误判为组件未启用。
- 下一步仅补充 Debug 构建的异常类型/堆栈观测，排除初始化失败原因；不在正式 UI 或日志中暴露音频 URL、凭据或 User API 内容。

## 2026-07-16 定位结论与修复方案

- 实际异常为 `audio_service` 的 `PlatformException`：`MainActivity` 使用普通 `FlutterActivity` 时，插件检测到它没有使用插件持有的 FlutterEngine，拒绝 `AudioService.init`。这解释了组件已启用、会话已创建但没有任何可播放状态的现象。
- 已核对当前锁定的 `audio_service 0.18.19` 源码：官方 `AudioServiceActivity` 只负责提供该共享引擎。下一步恢复该父类，同时保留 service/receiver 默认 disabled；这样冷启动不会绑定可用服务，首次播放前才启用官方组件并通过正确引擎初始化。

## 2026-07-16 真机验证调整

- 不再使用公共示例 MP3。按需求改以用户提供的 LX 音源脚本 `https://raw.githubusercontent.com/pdone/lx-music-source/main/lx/latest.js` 验证“远程地址导入、启用、真实搜索/取链、播放”的业务闭环；该地址只用于真机输入，不写入应用默认配置或测试 fixture。

## 2026-07-16 恢复性修复：初始化失败可重试

- 复查首次播放失败路径发现：`JustAudioEngine` 将 `AudioService.init` 的 Future 缓存为 `_handler`，并用两个 `.then` 建立订阅。若初始化失败，缓存会永久保持 rejected Future，后续播放无法重试，两个无错误处理的订阅 Future 还会产生额外未处理异常。
- 本次将改为仅在 handler 成功创建后同步订阅快照和媒体命令；初始化失败时清除同一轮缓存并把原始错误交回调用方。这样用户修复 Activity/服务条件后可再次播放，不需要重启应用；不改变业务 `AudioEngine` 接口或媒体会话协议。

## 2026-07-16 真机阻断：按需禁用 service 不能恢复绑定

- 使用真实 LX 音源点播时，SM-N986U / Android 13 日志显示 `AudioService.init` 失败：`Unable to bind to AudioService`。排除 User API 后确认原因是 `AudioServiceActivity` 在 Flutter 插件附着时就连接 `AudioService`；此前 manifest 默认 disabled，首次播放才启用已晚于连接生命周期。
- 修复：`AudioService` 恢复 manifest 默认可用，并在 `MainActivity.onCreate` 于 `super.onCreate` 前恢复已被旧版本持久化的 disabled 状态；背景通道只按需开关 `MediaButtonReceiver`。这优先保证可播放闭环，但会恢复空闲 service/session 现象，原“冷启动 0 session”验收从通过改回待收口，不能据此把 B4-22 标记完成。
- 后续验收入口：重新安装 Debug APK 后，先确认 LX 导入和取链，再检查首次 `AudioService.init`、播放态通知/锁屏、暂停、停止后的 receiver 与冷启动会话状态。
