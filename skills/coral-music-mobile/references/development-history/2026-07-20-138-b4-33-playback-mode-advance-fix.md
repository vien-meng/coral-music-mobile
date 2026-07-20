# B4-33 播放模式切歌修复

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 目标与范围

修复列表循环完成后重复播放当前歌曲，以及随机播放、单曲循环不稳定的问题。复用现有队列和播放器控制器，不新增依赖或平台分支。

## 根因

- 音频引擎在进入完成态后，进度流和时长流仍可能携带同一 `completed` 状态继续发快照；控制器对每个快照重复推进队列，短队列会绕回原曲，随机和单曲循环也会重复启动。
- `replaceQueue()` 创建新状态时未保留用户当前选择的播放模式，点选新列表后会静默恢复列表循环。
- 手动上一曲/下一曲和系统媒体按键固定调用顺序偏移，没有在随机模式下复用随机候选，因此看起来仍是列表循环。

## 验证要求

- 同一轮播放收到重复完成事件时只推进一次。
- 列表循环、单曲循环和随机播放分别保持正确行为。
- 替换播放队列后保留当前播放模式。
- 随机模式下手动上一曲/下一曲选择非当前的随机候选，而不是相邻歌曲。
- Android 真机复验真实曲目切换。

## 实施与验证

- `PlayerController` 只在当前状态仍为 `playing` 时接受完成快照，并在推进队列前先切到 `completed`；同一轮后续完成/进度快照不会再次推进。CUE 分轨边界使用相同状态门槛。
- `PlaybackQueueController.replaceQueue()` 保留现有 `PlaybackMode`，随机历史仍随新队列重置。
- `test/player_controller_test.dart` 增加三种模式连续发送两次完成快照的回归；`test/playback_queue_test.dart` 增加替换队列保留模式回归。
- 相关 `dart format`、针对性 `dart analyze` 和 `git diff --check` 通过。
- Samsung SM-N986U / Android 13 已完成 Debug APK 构建、安装和首帧启动。
- `flutter test test/playback_queue_test.dart test/player_controller_test.dart` 被工作区外 Flutter SDK 缓存锁权限拦截；提权重试因审批服务返回 503 未执行。读取真机界面树的审批也返回 503，尚未完成人工三模式切歌，因此任务保持 `DOING`。
- 2026-07-20 用户真机确认随机模式手动上一曲/下一曲仍表现为顺序切歌。根因是 `selectNext()`/`selectPrevious()` 固定按偏移选曲；现已在随机模式复用 `_selectShuffle()`，因此播放页和系统媒体命令同时生效。
- `test/playback_queue_test.dart` 使用固定随机源证明手动上一曲和下一曲均选择非相邻候选；针对性格式与静态分析通过，修复版已重新构建并安装到 Samsung SM-N986U。
- 本轮 `flutter test` 再次因外部审批服务返回 HTTP 503 而未启动；该 503 发生在 Codex 权限审批阶段，不是 Flutter 测试失败。
