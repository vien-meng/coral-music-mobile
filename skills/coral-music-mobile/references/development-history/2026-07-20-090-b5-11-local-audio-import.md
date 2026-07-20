# B5-11 本地音频导入、目录扫描与播放闭环

- 阶段：Batch 5 / Phase 4
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标与范围

支持用户选择本地音频文件，以及授权目录后的递归扫描；导入元数据、封面与同目录 LRC，并加入现有列表、队列、历史和离线播放链。

不做：把本地文件上传到服务器、交给 User API 取链，或因本地文件失败而回退到在线音质/换源。

## 实施顺序

1. 接入跨平台文件与目录选择入口，并在三端单独确认目录权限语义。
2. 实现扩展名过滤、递归扫描、失败项报告和 `TrackSourceKind.local` 快照。
3. 复用既有音频引擎、本地 LRC 加载与 SQLite 列表，不新增另一套播放器或媒体库。

## 当前风险

iOS、Android 与鸿蒙对目录授权与持久 URI 的实现不同；先完成共享扫描/导入模型，平台授权恢复在真机阶段验收，不假定三端行为相同。

## 实际修改

- 继续任务：现有导入已能扫描文件和目录，但本地同目录封面没有进入 `Track`，且播放/列表封面控件只按网络 URI 渲染。此轮先补本地 `cover`/`folder` 图片发现与 `file://` 图片渲染，不引入未经鸿蒙验证的 ID3/FLAC 标签依赖；嵌入封面和完整标签读取保留到三端可行性确认后。
- 新增共享 `LocalAudioScanner`：支持单文件集合和目录递归扫描，过滤常见音频扩展名，跳过缺失/非音频文件，并生成只带本地 URI 的 `TrackSourceKind.local` 曲目。
- 扫描器不导入网络、播放器、User API 或音质选择依赖；后续选择器只负责提供用户授权的路径。
- 已声明 `file_picker` 作为系统文件/目录授权入口；待依赖解析后接入“我的列表”的导入操作。选择器不承担扫描、元数据或播放逻辑。
- 已接入“我的列表”详情页：用户明确选择“音频文件”或“目录扫描”后，扫描结果逐首去重写入当前列表；导入结果以成功数量反馈。
- 已确认既有 `lyricProvider` 与 `PlaybackResolver` 对 `file://` 直接生效：本地曲目优先读取同目录 LRC，且不会调用在线歌词、User API 或在线音质降级。目录权限/遍历异常现在作为跳过项反馈，不会中断已扫描曲目。
- 本轮补齐同目录封面：扫描器按目录缓存并识别 `cover.*` / `folder.*` 图片，普通本地曲目和 CUE 曲目都会获得 `file://` 封面 URI。新增共享 `CoverImage`，列表、迷你播放器、播放详情、队列和下载页按 URI scheme 分别使用 `Image.file` 或网络图片，修复了此前本地封面无法显示的问题。`flutter analyze` 与 `flutter test test/local_audio_scanner_test.dart` 通过。
- 封面、LRC 与 CUE 作为已识别的旁路文件不再被计入“跳过”报告，避免目录扫描把正常的封面/歌词误报为失败；真实未知文件和遍历异常仍保留报告。最新 `flutter analyze`、本地扫描/下载恢复/WebDAV 目录三项最小测试及 `git diff --check` 通过。
- CUE 已接入目录扫描；基础元数据在未接入平台 ID3 读取器时从常见“歌手 - 歌名”文件名提取，平台标签/封面读取仍作为后续真实调用方工作保留。
- 复用播放页既有 `AudioFileProbe`，现已对 `file://` 读取前 64 KiB 并解析 MP3/FLAC 头；本地导入和已下载歌曲播放时会显示实际可解析的格式、码率和采样率，不需要新增媒体元数据依赖。
- `flutter pub get`、`dart format`、`flutter analyze`、`git diff --check` 通过。真实 Android/iOS/鸿蒙目录授权、媒体元数据/封面与 CUE 的平台验收仍待继续。
- 2026-07-20：开始补齐共享 MP3 ID3v2 标签读取。桌面端通过 `music-metadata` 读取完整格式，移动端没有已验证的三端等价依赖；本轮使用 Dart 二进制读取实现实际调用方所需的标题、歌手、专辑、年份、流派和封面，其他格式继续安全回退到现有文件名/同目录封面路径。
- 2026-07-20：完成 MP3 ID3v2.3/v2.4 与 FLAC Vorbis Comment/Picture 的共享读取；扫描优先使用嵌入标题、歌手与专辑，年份/流派存入既有 `Track.extra`，内嵌封面落入应用私有缓存后以 `file://` URI 复用现有组件显示。标签/扫描器聚焦测试、`flutter analyze` 与 `git diff --check` 通过。M4A/AAC/Ogg/Opus 的标签读取、真实三端授权与格式矩阵仍待验收。
- 2026-07-20：包含本地元数据/分类/主题更新的 Android Debug APK 已成功安装至 Samsung Android 13 真机 `R5CR70B7SMA`；开始补 M4A 容器标签，继续保持所有解析在共享 Dart 层。
- 2026-07-20：M4A `moov/udta/meta/ilst` 的常用标题、歌手、专辑、日期、流派和 `covr` 封面读取已完成，MP3/FLAC/M4A 聚焦解析测试通过；继续补 Ogg/Opus 的 Vorbis Comment 与封面，AAC 若含 ID3 已由同一检测路径支持。
- 2026-07-20：完成 Ogg/Opus Vorbis Comment（含 `METADATA_BLOCK_PICTURE`）、WAV `RIFF INFO` 读取；常见 P0 格式 MP3、FLAC、WAV、M4A、AAC（ID3）、Ogg、Opus 均有真实标签路径，非标准/缺失标签安全回退文件名和同目录封面。MP3/FLAC/M4A/Ogg/WAV 标签、扫描器和分类共 9 条聚焦测试，以及 `flutter analyze`、`git diff --check` 通过。仍待真实三端文件授权、播放时长/封面视觉与 AIFF/APE 标签的 P1 格式矩阵验收。
- 2026-07-20：含完整本地格式标签解析的 Debug APK 已重新构建并成功安装至 Samsung Android 13 真机 `R5CR70B7SMA`；真实媒体样本导入和 iOS/鸿蒙权限恢复仍作为三端验收，不以模拟夹具替代。
