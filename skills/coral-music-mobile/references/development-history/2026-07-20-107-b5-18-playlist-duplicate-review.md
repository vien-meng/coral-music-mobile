# B5-18 列表重复检测与复核

- 阶段：Batch 5 / Phase 4
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：2026-07-20

## 目标、范围与依赖

在现有列表批量选择操作中增加安全的重复识别：保留最早歌曲，将后续“同名、同歌手、同专辑、同长度”的曲目预选，由用户自行删除、移动或复制。

依赖 B5-07 批量选择/删除和 B5-17 导入。不会自动删除、不按模糊歌名猜测、不跨列表合并，也不修改下载或播放队列。

## 实施记录

- 2026-07-20：开始实现纯函数判定与列表详情入口。
- 新增 `findDuplicateTrackIds`，仅在规范化后的歌名、歌手、专辑和时长全部相同的情况下选择后续项，始终保留第一个条目。
- 列表详情页在搜索框上方增加“识别重复歌曲”；命中项进入现有批量选择态，用户可继续删除、复制、移动或取消选择。
- 实际修改：`lib/features/library/data/playlist_duplicates.dart`、`view/library_page.dart`、`test/playlist_duplicates_test.dart`。
- 验证：`dart format`、`flutter analyze`、`flutter test test/playlist_duplicates_test.dart test/playlist_transfer_codec_test.dart`、`git diff --check` 通过。

## 已知限制与下一步

- 不做模糊匹配，以避免不同专辑版本或现场版被误删；需要人工确认后才会执行删除。
- 下一步回到 Phase 6，补齐本地备份与可回滚恢复预览。
