# B4-21 同目录本地 LRC 优先读取

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

本地 `file://` 曲目先读取同目录 LRC，再调用在线/User API 歌词；覆盖同名、歌手 - 歌名、歌名 - 歌手命名。

不做：content URI、目录扫描、模糊匹配、GBK 编码、本地歌词编辑或缓存。

## 验收

- 同目录命中 LRC 时不请求在线音源；未命中时保留现有 User API 歌词流程。

## 当前进度

- 新增本地歌词读取器，使用曲目文件的父目录和四种固定候选命名；文件上限 512 KiB，只接受 UTF-8，文件名中的路径分隔符会被替换。
- `lyricProvider` 先读取本地歌词，未命中才走受限 User API；UI 继续复用既有 LRC 时间轴。
- 已新增临时目录 LRC 命中测试；聚焦 `flutter test`、`flutter analyze --no-fatal-infos` 通过。
- 不可访问、损坏或非 UTF-8 的候选本地文件会跳过并呈现空歌词，避免本地文件错误阻断歌词页或越界调用 User API。
- 已按四类来源边界修正：本地、下载和 WebDAV 在 LRC 未命中时返回空歌词，不会调用 User API；只有在线曲目可以请求已启用音源的歌词。新增 `test/lyric_controller_test.dart` 覆盖三个非在线来源零 User API 调用。
- 验证通过：`dart format lib/features/player/state/lyric_controller.dart test/lyric_controller_test.dart` 和 `flutter test test/lyric_controller_test.dart -r compact`。

## 风险与后续

- Android SAF `content://`、目录扫描、GBK/UTF-16、模糊匹配和歌词缓存尚未实现；本地导入任务完成后需三端真机验证，任务保持 `DOING`。
