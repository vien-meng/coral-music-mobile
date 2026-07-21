# B4-39 本地歌词在线兜底与格式播放矩阵

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 目标

核对本地导入格式与实际播放链路，明确 FLAC 支持范围；保持同目录 UTF-8 LRC 最高优先级，并在本地歌曲没有可读歌词时，以歌名和歌手调用已有独立歌词服务。该兜底不得调用 User API，也不得改变下载和 WebDAV 的离线行为。

## 验证口径

- `.flac` 可被扫描、读取 FLAC 标签/嵌入封面，并直接交给系统音频引擎。
- 本地同目录 LRC 命中后，不访问在线歌词服务。
- 本地歌曲无 LRC 时，按标题和歌手调用独立歌词搜索；下载和 WebDAV 仍不发起该请求。
- 真实音频解码必须由重新构建后的 Android 真机使用各格式有效媒体样本逐首播放确认；仅后缀识别不作为解码通过证据。

## 实施与验证

- `LocalAudioScanner` 已包含 `flac`；`readLocalAudioMetadata()` 解析 FLAC Vorbis 标签和嵌入封面；`PlaybackResolver` 对本地 `file://` URI 直接返回，不进入 User API。新增回归用例覆盖 FLAC 扫描及 URI 直通。
- `lyricProvider` 现在先读取同目录 LRC；只有本地歌曲未命中时才继续现有的来源歌词/LrcLib 链，LrcLib 已按歌名、歌手（可用时再带专辑与时长）检索。下载与 WebDAV 在缺词时仍立即返回，且所有本地来源均不调用 User API。定向检查覆盖同目录 LRC 优先和本地缺词回退。
- 已执行 `dart format`、定向 `dart analyze`（无问题）及 `git diff --check`。
- 定向 `flutter test` 需要工作区外 Flutter SDK 缓存；按流程申请访问时外部审批服务返回 HTTP 503，未绕过。2026-07-21 已在 SM-N986U 安装并启动当前 Debug APK，Dart VM 成功连接且启动无崩溃；系统 `AudioCapabilities` 明确报告 `audio/x-ms-wma` 不支持。当前仍没有可用于逐格式播放及本地 LRC 回归的真实媒体样本，任务保持 `DOING`。
