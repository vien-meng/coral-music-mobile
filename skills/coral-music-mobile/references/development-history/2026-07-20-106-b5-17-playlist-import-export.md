# B5-17 列表导入与导出

- 阶段：Batch 5 / Phase 4
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：2026-07-20

## 目标、范围与依赖

为本地用户列表提供单列表 JSON 导入与导出，并兼容桌面端 `playListPart_v2` 文件。导入创建新列表，按既有 `(playlist_id, track_id)` 主键跳过重复歌曲；导出复用桌面端的歌曲字段，方便在桌面端直接导入。

依赖 B5-01/B5-03 的 SQLite 列表存储和已安装的 `file_picker`。不实现完整备份恢复、跨设备同步、服务器上传或本地文件复制。

## 桌面端对照

- `coral-music-desktop/src/renderer-react/services/listService.ts`
- 桌面端使用 `{ type: 'playListPart_v2', data: { id, name, list } }`，并在导入时处理旧版 `playListPart`。
- 移动端保持该容器格式；在线来源映射为现有 `Track`，本地/WebDAV 文件路径仅原样迁移，凭据不进入导出文件。

## 实施记录

- 2026-07-20：开始实现纯 Dart 格式编解码、SQLite 原子导入和文件选择/保存入口。
- 新增 `PlaylistTransferCodec`：导出 `playListPart_v2`，导入时兼容桌面端 v1/v2 容器、旧 `flac32bit` 名称、在线/本地/WebDAV 曲目与音质字段；不支持的来源或无效条目自动跳过。
- `LibraryStore` 在一个 SQLite transaction 中创建列表并写入歌曲；现有主键约束继续去重，界面显示新增和跳过数量。
- 我的列表页增加 JSON 导入；列表详情增加 JSON 导出。导出路径不包含 WebDAV 授权或 User API 脚本/凭据。
- 实际修改：`lib/features/library/data/playlist_transfer_codec.dart`、`library_store.dart`、`state/library_controller.dart`、`view/library_page.dart`、`test/playlist_transfer_codec_test.dart`。
- 验证：`dart format`、`flutter analyze`、`flutter test test/playlist_transfer_codec_test.dart`、`git diff --check` 通过。

## 已知限制与下一步

- 系统文件保存回调的路径语义、桌面导入实测与 iOS/鸿蒙文件选择验收留给三端收口；本任务不伪造真机验证。
- 下一任务：B5-18 列表重复检测与批量清理。
