# B4-01 最小可播放闭环：音频引擎、取链与受限 User API

- 阶段：Batch 4 / Phase 0、3 提前项
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-15
- 完成时间：未完成；等待 Android 真机解锁后的播放验收

## 目标、范围、不做内容与依赖

实现在线 `Track` 的最小播放闭环：解析 URL、加载、播放、暂停、seek、进度状态，以及仅供调试的 User API `musicUrl` 动作。依赖 B2-05、B3-01、B3-04 和计划修订 019；不实现后台媒体会话、队列自动下一首、歌词、缓存、音质降级、下载或完整 User API 管理。

## 桌面端基线与确认行为

对照 `services/playerRuntime/musicUrlResolver.ts`、`services/musicSdkRuntime.ts`、`main/modules/userApi/renderer/preload.js`。User API 通过 `lx`/`coral` 事件桥注册请求处理器；`musicUrl` 只接受最长 8192 字符的 HTTP(S) URL，桌面请求超时为 20 秒。

## 实施方案与平台差异

- 共享 Dart 层新增 `AudioEngine`、`PlaybackResolver`、最小 `SourcePluginRunner` 与播放状态；UI 只调用控制器。
- 音频使用 `just_audio` 处理 HTTPS URL；不启用其本地 HTTP proxy、缓存或自定义 headers，保持 iOS ATS 边界。
- Android 首先使用受限 `WebView` 原生实现 User API 桥：无文件选择、原生对象、剪贴板或任意 MethodChannel 暴露；仅注入最小 `lx` 对象并回传 `musicUrl`。
- iOS、鸿蒙在对应沙箱尚未验证前必须显式返回不支持；不能执行脚本或绕过 TLS。HAP 继续验证共享层编译。

## 验收、风险与恢复入口

- Android 真机：固定 HTTPS 音频 URL 与受限 User API 各能完成播放、暂停、seek。
- 超时、脚本异常、非 HTTPS URL、超长返回与错误状态不得崩溃应用或泄露脚本内容。
- 若 `just_audio_harmonyos` 不能通过 HAP 编译，撤回依赖并改为 MethodChannel 音频实现；若 Android WebView 不能隔离，User API 子项标记 `BLOCKED`。
- 后续恢复入口：`lib/features/player/`、`lib/features/user_api/`、`android/app/src/main/` 和本文件。

## 关联

关联计划修订 019、P0-04、P0-09、P3-01、P3-02、P6-01。

## 实际修改与关键接口

- `lib/features/player/data/audio_engine.dart`：`AudioEngine` 与 `JustAudioEngine`，支持 HTTPS URL 加载、播放、暂停、seek、状态和错误流。
- `lib/features/player/data/playback_resolver.dart`：在线来源通过 User API `musicUrl` 解析；本地、下载、WebDAV 明确拒绝进入此链。
- `lib/features/player/data/user_api_runner.dart`：MethodChannel `UserApiRunner`，限制脚本 256 KiB、播放 URL 8192 字符且必须为 HTTPS。
- `lib/features/player/state/player_controller.dart`：连接解析器和音频引擎，提供播放、暂停、seek、调试 HTTPS URL。
- `lib/features/player/state/user_api_debug_controller.dart`、`view/user_api_debug_page.dart`：设置页内临时脚本和 HTTPS 音频调试入口；不保存脚本。
- `lib/features/player/view/mini_player.dart`：真实播放/暂停状态、错误和可 seek 滑块。
- `android/app/src/main/kotlin/com/coral/music/mobile/UserApiRunner.kt`：受限 Android WebView 桥，仅暴露 `lx/coral` 的 `on`、`send`、`request` 最小子集；原生请求强制 HTTPS、GET/POST、20 秒超时、64 KiB 请求体和 1 MiB 响应上限。
- `android/app/src/main/kotlin/com/coral/music/mobile/MainActivity.kt`、`AndroidManifest.xml`：注册 MethodChannel 及网络权限。
- `pubspec.yaml`、`pubspec.lock`：新增 `just_audio` 和 `just_audio_harmonyos`；未接入后台媒体服务。
- `test/player_controller_test.dart`：验证 User API URL 先解析、再加载、再播放。

## 重要决策与调整

`just_audio` 原生请求不使用本地 HTTP proxy、缓存或自定义 headers，避免为播放器放宽 iOS ATS。鸿蒙使用 `just_audio_harmonyos` 的插件实现；完整后台媒体服务和 iOS/鸿蒙 User API 运行时不在本任务加入。Android WebView 禁止 WebView 网络、文件、内容、数据库和多窗口访问；脚本网络只能经过受控桥。

## 验证

- `dart format lib test`、`flutter analyze`、`flutter test`：通过；在线冒烟按默认开关跳过。
- `flutter build apk --debug`：通过，产物 `build/app/outputs/flutter-apk/app-debug.apk`。
- `flutter install -d R5CR70B7SMA`：通过，安装到 SM N986U / Android 13；应用启动并加载真实酷我排行榜。
- `flutter build hap --debug`：通过，生成 unsigned HAP；DevEco 调试签名未配置。
- `flutter build ios --debug --no-codesign`：通过，生成 `build/ios/Debug-iphoneos/Runner.app`。
- 真机未完成项：设备在进入“设置 → 播放调试”前锁屏，未绕过用户锁屏。恢复后粘贴以下受控示例，点击“启用临时调试音源”，在酷我列表选歌并点迷你播放器播放；随后用滑块 seek：

```js
lx.on('request', async ({ action }) => {
  if (action !== 'musicUrl') throw new Error('unsupported')
  return 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'
})
lx.send('inited', {
  sources: { kw: { type: 'music', actions: ['musicUrl'], qualitys: ['128k'] } },
})
```

## 当前状态、风险与下一步

任务保持 `DOING`：共享逻辑和三端构建完成，但 User API 取链、实际出声和 seek 尚未在已连接 Android 真机验证。iOS/鸿蒙 User API 运行时尚未实现，当前会安全拒绝。设备解锁后优先完成上述三项验收，再决定是否进入后台媒体与完整 User API 管理。

## 2026-07-15 构建兼容性调整

- `audio_session 0.2.4` 要求 Android `minSdk 24`，故将 `android/app/build.gradle` 从 Flutter 模板的 API 21 提升为 API 24；不使用 `tools:overrideLibrary`，避免在低版本系统留下未验证的运行时崩溃风险。
- 该版本的 Android 子工程以 Java 8 编译、Kotlin 默认目标 17，会被 Kotlin 的目标一致性检查拒绝。项目在 `android/gradle.properties` 将该检查降为 warning，使 Android 构建能继续；APK 已生成，但这不是实际音频真机验收的替代，B4-01 继续保持 `DOING`。
