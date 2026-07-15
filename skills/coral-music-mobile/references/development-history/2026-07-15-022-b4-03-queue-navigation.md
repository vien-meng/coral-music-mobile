# B4-03 队列前后切歌基础

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-15
- 完成时间：未完成

## 目标、范围、不做内容与依赖

在现有内存队列和已验证的 Android 播放闭环上，补齐播放详情页的上一首、下一首操作。队列索引必须首尾循环，并在选择新歌曲后调用现有 `PlayerController.playTrack`，不在 UI 中直接解析 URL 或访问音频引擎。

依赖 B2-05、B4-01、B4-02。不实现播放模式、随机历史、自动下一首、错误跳过、持久队列或共享队列抽屉；它们留给 P3-03 后续切片。

## 桌面端基线与确认行为

对照 `coral-music-desktop/src/renderer-react/stores/domains/playerStore.ts` 的 `playNext`、`playPrev` 和 `getQueueSibling`。桌面端在队列中寻找相邻歌曲，在循环模式下首尾衔接，再交由统一的 `playMusic` 处理；移动端本切片采用同一“队列选项 + 统一播放控制器”边界。

## 实施方案、数据与平台差异

- 扩展现有 `PlaybackQueueController`，复用不可变队列状态，不创建第二套播放器状态。
- 在播放详情页使用已有 `PlayerController` 播放被选中的队列歌曲；平台音频实现不分叉。
- 单元测试覆盖首尾循环、空队列与播放详情的可见控制。真机播放复用 B4-01 的 Android 验收路径。

## 风险、恢复入口与关联

在线歌曲仍受 User API 音源可用性限制；上一首/下一首不会绕过取链失败。恢复入口为 `lib/features/player/state/playback_queue_controller.dart`、`lib/features/player/view/player_detail_page.dart` 和本记录。

关联 B2-05、B4-01、B4-02、P3-03、功能矩阵“队列”“播放模式”。

## 实际修改与验证

- `lib/features/player/state/playback_queue_controller.dart`：新增 `selectNext`、`selectPrevious`，空队列返回 `null`，非空队列首尾循环并保留来源上下文。
- `lib/features/player/view/player_detail_page.dart`：新增上一首/下一首按钮；按钮从队列控制器取得歌曲后调用已有 `PlayerController.playTrack`，未直接访问解析器或音频引擎。
- `test/playback_queue_test.dart`：覆盖从首项上一首跳至末项、从末项下一首回到首项。
- `dart format`、`flutter analyze`、`flutter test test/playback_queue_test.dart test/app_shell_test.dart`：通过，12 个测试通过。
- Android 真机（SM-N986U / Android 13）：在 B4-01 的受控 `kw` 音源下打开播放详情，点击下一首后歌曲标题、歌手与封面变为排行榜第二项，证明队列索引和取链入口已切换；媒体焦点仍为 `USAGE_MEDIA` active。

## 当前状态、风险与精确恢复入口

状态保持 `DOING`。真机切换后的详情页一度显示“已暂停”，尚未确认每次切歌都立即恢复 `playing` 状态；不得据此把“队列切歌播放”标记 `DONE`。下一步从 `JustAudioEngine.load/play` 的 player-state 事件顺序开始，记录切歌时的 `processingState` 和 `playing`，再决定修复位置。随后补播放模式、自动下一首、错误跳过和随机历史。
