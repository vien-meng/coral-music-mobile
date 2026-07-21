# B5-22 Android DSD 流式解码播放

- 阶段：Batch 5 / Phase 4
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 目标

按桌面端现有路径实现 Android 的 DSF/DFF 秒播：原生解码器持续输出 WAV 流，现有 `just_audio` 播放本地流地址；不得先生成整首临时 WAV。

## 桌面基线

桌面端的 `externalDecoderRuntime.ts` 启动内嵌 FFmpeg；`externalDecoderStreamArgs.ts` 以 `-f wav pipe:1` 输出，localhost HTTP 服务把 stdout 直接交给 HTML Audio。DSF/DFF 由 `ffmpeg` 流式 provider 处理，不走全量 `transcodeExternalDecoder()` 临时文件路径。

## 阻塞

当前工作区没有 Android FFmpeg 源码、Android NDK、可用 Android AAR 或 ABI 对应的 `libav*`/FFmpeg `.so`。可找到的 `/opt/homebrew/bin/ffmpeg` 和桌面 `ffmpeg-static/ffmpeg` 均为 macOS arm64 Mach-O 文件，不能在 Android 运行。尝试安装用户指定的非 GPL `ffmpeg_kit_flutter_new_full: ^4.1.0` 时，外部审批服务返回 HTTP 503，依赖未写入锁文件或缓存。

不能只添加 Dart/MethodChannel 壳：`just_audio` 的 Android 后端不提供 DSF/DFF 解码，空桥接会把不支持伪装成已支持。

用户随后手动安装了 `ffmpeg_kit_flutter_new: 4.5.1`。已核验该包 README 标识为 Full-GPL，Android Gradle 依赖为 `com.antonkarpenko:ffmpeg-kit-full-gpl:2.2.1`。本项目当前为 MIT 许可，不能在未经项目版权人明确决定改为 GPLv3 的情况下分发该依赖。已改用本机缓存的非 GPL `ffmpeg_kit_flutter_new_full: 2.4.1`，其 Android 依赖为 `com.antonkarpenko:ffmpeg-kit-full:2.2.1`，README 声明 LGPL 3.0。该插件仍没有 OpenHarmony 平台实现。

切换 manifest 后，`flutter pub get --offline` 需要在工作区外 Flutter SDK 缓存创建锁文件；外部审批服务返回 HTTP 503。用户随后完成了本机依赖解析，`pubspec.lock` 与 Dart 包配置均已指向非 GPL `_full: 2.4.1`。但 Gradle 缓存中仍没有 `com.antonkarpenko:ffmpeg-kit-full:2.2.1` 的 Android AAR，因此尚不能构建或宣称 DSD 已启用。

## 依赖状态

`ffmpeg_kit_flutter_new_full: 2.4.1` 自带 `implementation("com.antonkarpenko:ffmpeg-kit-full:2.2.1")`。用户提供的 `:app:dependencyInsight` 和 Gradle 构建成功证据，以及后续生成的 Debug APK，均证明该 AAR 已作为传递依赖解析到 App；无需重复手动添加。发布版仍需核验 `arm64-v8a`、`armeabi-v7a` 产物和 LGPL 分发声明。

## 实施与验证

- 已接入非 GPL `ffmpeg_kit_flutter_new_full: 2.4.1`。Android 本地 `.dsf`/`.dff` 会启动单线程异步 FFmpeg 会话，完成后输出应用临时目录中的标准 PCM WAV，再交给现有 `just_audio` URI 播放链路；切歌、停止和解码失败会删除临时文件。DSF/DFF 分别按自动探测和 IFF 输入解析，输出 44.1 kHz、16-bit、双声道 PCM。普通 WAV 保持系统直通；只有在文件前 64 KB 发现 DTS 帧同步字的伪 WAV 才异步下混为双声道 PCM，避免无谓转码。
- 新增 `test/dsd_audio_stream_test.dart` 覆盖 DSF/DFF 本地 URI 识别。`dart format --output=none --set-exit-if-changed`、定向 `dart analyze` 与 `git diff --check` 已通过。
- 2026-07-21 11:16 重新生成 `build/app/outputs/flutter-apk/app-debug.apk`（103,790,260 bytes），证明 Android FFmpegKit 原生依赖参与 Debug 构建。`flutter run` 会话未返回最终安装状态；尚未提供真实 DSF/DFF 文件，首播、seek、切歌和后台验证仍待完成。
- WAV 杂音反馈后，检查 `/Users/vien.meng/Documents/测试声音/19 丹尼的梦想.wav`，其 `wav` 容器实际封装 44.1 kHz、7 声道 DTS；系统按 PCM 直放会产生杂音，和桌面端历史场景一致。Android `.wav` 同样改走 FFmpeg PCM 规范化流并固定下混为双声道；DSF/DFF 也固定为 44.1 kHz、16-bit、双声道 PCM。
- 用本机 FFmpeg 对该 DTS WAV、`06-POWDER SNOW.dsf` 和 `03. 为什么春天会迟到.dff` 分别执行移动端同等参数的 1 秒转码，三个结果均通过 FFprobe 验证为 `pcm_s16le|44100|2|16`。2026-07-21 13:44 已重新构建、安装并启动 Debug APK 到 SM-N986U，等待同一批 WAV/DSF/DFF 文件真机复测。
- 真机复测显示三首文件仍卡住；运行日志确认 Dart loopback/FIFO 方案出现 `Connection refused` 和 `StreamSink is bound to a stream`，不适合作为 Media3 音频源。已移除该路径，改为临时 PCM WAV；这恢复播放与 seek，但不再具备桌面端的边解边播，需要原生 Media3 `DataSource` 才能恢复秒播。2026-07-21 13:54 已重新构建、安装并启动修复版到 SM-N986U，待用户复测原文件。
- 考虑低端设备的 CPU/磁盘负载，移除所有 WAV 的转码：普通 PCM WAV 直通，只有检测到 DTS 帧同步字的伪 WAV 才转码。FFmpeg 调用改为单线程异步会话，避免同步原生调用占住界面；DSF/DFF 仍需等待整首临时文件生成，原生 Media3 数据源仍是后续秒播路径。
- 转码准备阶段复用既有 `AudioEngineStatus.loading`，播放详情和歌词页共享的主播放按钮展示禁用的加载指示器，避免用户误以为点击无效。文件信息探测增加 DSF、DFF 和 WAV 容器头解析：DSF/DFF 用采样率乘声道数显示 DSD 原始码率；DTS WAV 识别帧同步并使用 WAV byte rate 显示源编码码率，始终展示原文件信息而非转码后的临时 PCM WAV。
