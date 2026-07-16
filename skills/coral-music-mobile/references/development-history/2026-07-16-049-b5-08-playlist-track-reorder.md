# B5-08 列表歌曲拖动排序

- 阶段：Batch 5 / Phase 4
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

支持用户在未筛选、未批量选择的列表详情中拖动歌曲排序，并将完整顺序写回 SQLite。依赖 B5-03/B5-06/B5-07；本任务不实现置顶、按字段排序或拖动跨列表移动。

## 桌面端对照

- `coral-music-desktop/src/main/worker/dbService/modules/list/` 对歌曲顺序单独维护，删除/移动后刷新顺序。
- 确认行为：排序只变更当前列表成员的位置，不能因筛选的局部视图而损坏未显示歌曲的相对顺序。

## 实施方案、依赖与验收

- 用 Flutter `ReorderableListView`；拖拽仅在完整列表视图开放，筛选或批量模式下禁用。
- 存储层通过单一 transaction/batch 回写全量 `position`。
- 验收：前后拖动、重启后顺序、筛选时不可误排；真机触控验收后补录。

## 当日实施进度

- 已增加 `saveTrackOrder`，用单一 SQLite transaction/batch 写回当前列表的完整位置序列。
- 列表详情已采用原生 `ReorderableListView`；仅无关键词、无来源筛选、无批量选择时展示拖拽手柄。
- 拖动完成后重新从存储读取顺序；搜索、来源筛选和批量选择时维持只读排序，避免局部列表损坏全量位置。
- 已通过 `dart format`、`flutter analyze`、`flutter test test/player_controller_test.dart`（3 项通过）与 skill 格式校验；真机触控和跨重启排序验收待补录。
