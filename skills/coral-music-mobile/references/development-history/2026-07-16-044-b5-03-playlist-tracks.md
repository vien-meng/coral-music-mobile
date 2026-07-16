# B5-03 列表歌曲成员与去重

- 阶段：Batch 5 / Phase 4
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

为 SQLite 列表增加曲目成员表，保存跨重启可恢复播放所需的曲目基本字段，按 `Track.id` 去重，并让现有在线歌曲入口能够加入用户列表。本任务不实现跨列表复制、批量选择、导入导出、离线文件扫描或收藏专用列表。

## 桌面端对照

- `coral-music-desktop/src/main/worker/dbService/modules/list/statements.ts`：列表与歌曲成员分别存储、位置独立维护。
- 确认行为：同一列表不应重复加入同一首歌；列表中的歌曲保留来源、标题、歌手和显示顺序。

## 实施方案、依赖与验收

- 将 schema 从 v1 显式迁移至 v2，新增 `user_playlist_track`，以 `(playlist_id, track_id)` 作为主键。
- 曲目只保存业务恢复必需字段，不保存播放 URL、凭据或 User API 结果；恢复后仍由既有播放解析链取链。
- 依赖 B5-01、B5-02 与 `Track`。验收为加入、去重、读取、按位置播放；跨重启及三端真机后续补录。
- 恢复入口：`lib/features/library/data/library_store.dart`、在线歌曲行和列表详情页。

## 当日实施进度

- 已将数据库升级为 v2，并通过 `onCreate`/`onUpgrade` 明确创建 `user_playlist_track`。该表以 `(playlist_id, track_id)` 去重，保存来源、标题、歌手、专辑、时长、封面、本地 URI、可用音质和位置。
- 播放 URL、凭据和 User API 响应不入库；恢复后的在线歌曲仍走既有播放解析链。
- 已实现列表详情、列表内播放、单曲移除，以及排行榜、搜索、歌单详情三个在线入口的“添加到我的列表”选择器。
- 已执行 `dart format` 与 `flutter analyze`；本轮是 Dart/schema 变更，复用 B5-01 的三端原生插件构建证据，真机创建、去重和跨重启恢复待设备恢复后统一验收。
