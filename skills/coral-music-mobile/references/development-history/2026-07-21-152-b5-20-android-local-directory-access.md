# B5-20 Android 本地目录授权与格式扫描

- 阶段：Batch 5 / Phase 4
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 根因与目标

Android 的目录选择器将用户选中的 SAF 目录转换为普通路径，但应用未声明或申请媒体读取权限。`Directory.list()` 抛出访问异常后被扫描器作为跳过项吞掉，因此含有已支持 MP3、M4A、AAC、OGG、Opus、WAV 的目录也会显示导入 0 首。

按需申请 Android 的媒体音频读取权限，并将目录访问失败反馈给用户。补齐桌面端已经识别、测试目录中出现的 `dsf`、`dff`、`ac3`、`aif`、`m4r`、`wma` 扩展名，使导入阶段不因后缀丢失曲目；实际播放仍由平台解码器决定。

## 验证要求

- Android 授权已给出时不重复弹窗；拒绝时不进行静默空扫描。
- 目录无法读取时向用户显示可操作错误。
- 扫描器至少识别测试目录中的所有音频后缀。

## 实施与验证

- Android 清单声明 Android 13+ 的 `READ_MEDIA_AUDIO` 与 Android 12 及以下的 `READ_EXTERNAL_STORAGE`；`MainActivity` 在用户选择目录后按需请求一次权限，已授权时直接继续。
- 新增最小 `coral_music/local_audio` MethodChannel。其它平台没有该桥接时安全返回可扫描，不引入新的权限插件或存储实现。
- `LocalAudioScanner` 的结果包含可读错误；目录不可访问或权限被拒绝时，页面显示错误而非“已导入 0 首”。
- 扩展名过滤补齐 `dsf`、`dff`、`ac3`、`aif`、`m4r`、`wma`；`test/local_audio_scanner_test.dart` 覆盖截图中的全部格式后缀。导入不等同于保证播放，DSD/AC3/WMA 等仍取决于设备解码器。
- `dart format`、定向 `dart analyze` 与 `git diff --check` 已通过。`./gradlew :app:compileDebugKotlin` 因工作区外 Gradle 缓存锁被沙箱拒绝；申请缓存访问后外部审批服务返回 HTTP 503，未绕过。需要在服务恢复后编译并在 Android 真机选择该测试目录回归，任务保持 `DOING`。
