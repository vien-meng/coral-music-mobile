# P7-03 全局系统分享音频导入

- 阶段：Phase 7
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：2026-07-20

## 目标、范围与依赖

修复 Android 系统分享音频仅在“我的列表”页面已创建时才会被导入的问题。无论用户当前在排行榜、搜索或设置页，收到分享音频都应写入唯一的“分享导入”列表。

复用 Android 已复制到私有目录的路径、`LocalAudioScanner` 与 `LibraryStore`。不新增平台权限、不实现 iOS/Harmony 分享扩展。

## 实施记录

- 2026-07-20：发现原监听器位于 `LibraryPage`，它不是所有导航分支的常驻页面，故分享事件可能无人消费。将导入动作移动到应用根部并收敛到 `LibraryController`。
- 2026-07-20：根部监听会串行消费分享路径；导入控制器负责查找/创建唯一“分享导入”列表、扫描私有副本并利用列表主键去重。页面层不再负责导入，避免导航状态影响功能。
- 验证：`dart format`、`flutter test test/playback_queue_test.dart`、`flutter analyze` 与 `git diff --check` 均通过。

## 验收与下一步

- Android 外部分享仍需已解锁真机回归；iOS/Harmony 分享扩展未实现。
- 关联：`P0-07`、`P7-01`、`P7-02`。
