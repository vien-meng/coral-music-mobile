# B5-15 CUE 单文件分轨播放

- 阶段：Batch 5 / Phase 4
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标、范围与依赖

将本地目录中的标准 CUE 单文件导入为可从各自 `INDEX 01` 开始播放的分轨，并避免同一原始音频又作为整轨重复导入。依赖 B5-11 本地扫描、列表持久化和播放器。

不实现复杂 REM 字段、编码探测、多段混音、无损切换或服务端元数据；多文件 CUE 保持按各曲目声明的 FILE 解析。

## 桌面端行为与实现约束

桌面端 CUE 曲目属于本地媒体：不得请求 User API、在线取链或在线音质降级。移动端把分轨起止毫秒保存到 Track 的本地 extra 中；PlayerController 在没有用户恢复位置时从分轨起点 seek，并在到达同一文件的下一分轨起点时切歌。

## 实际修改、验证与后续

- 重写 CUE 解析：读取 `FILE`、专辑/曲目 `TITLE`、`PERFORMER`、`TRACK` 和 `INDEX 01`，生成每首的本地文件 URI、起止毫秒和可用时长；多文件 CUE 按每条曲目当前 FILE 处理。
- 目录扫描先解析所有 CUE，再跳过被 CUE 引用的原始音频文件，避免“整轨 + 分轨”重复；分轨仍继承同目录封面。
- SQLite schema 升级到 v6，列表和快照会保留 `Track.extra`，因此重启后 CUE 起止位置不丢失。PlayerController 在正常点播、自动下一首和单曲循环中按 CUE 起点 seek，并在下一分轨边界切歌。
- 新增单文件 CUE 解析/去重扫描回归；`dart format`、`flutter analyze`、`flutter test test/cue_parser_test.dart test/local_audio_scanner_test.dart test/player_controller_test.dart` 和 `git diff --check` 通过。
- 状态：DONE。真机格式矩阵、编码探测和 iOS/鸿蒙后台回归仍属于本地媒体平台验收。
- 2026-07-20：重新开启末曲总时长收口。已有 FLAC StreamInfo 已解析总采样数但未向扫描器暴露；本轮复用该信息填充 CUE 最后一轨的时长和 `cueEndMs`，不另建媒体解析器。
- 2026-07-20：`AudioFileInfo` 已公开可解析时长；FLAC 使用 StreamInfo 的真实总采样数，MP3 在可解析恒定码率和文件总大小时提供估算。目录扫描为 CUE 最后一轨补齐真实/可解析的 `duration` 与 `cueEndMs`，音频头/CUE/扫描聚焦测试、`flutter analyze` 和 `git diff --check` 通过。
- 2026-07-20：包含 CUE 末曲边界修正的 Debug APK 已成功安装至 Samsung Android 13 真机 `R5CR70B7SMA`；待真实 CUE/FLAC 样本导入、分轨切歌和后台回归确认。
