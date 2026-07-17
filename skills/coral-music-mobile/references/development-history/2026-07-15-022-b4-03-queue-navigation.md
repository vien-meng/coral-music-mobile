# B4-03 队列前后切歌基础

- 阶段：Batch 4 / Phase 3
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-15
- 完成时间：2026-07-17

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

## 2026-07-17 Android 真机：详情下一首恢复播放

- 使用用户指定的真实 LX 音源搜索“周杰伦”，点播《晴天》后进入播放详情；详情页点击可用的“下一首”。
- 9 秒后系统媒体会话为 `PLAYING`、位置 `8.025s`，元数据切换为《红尘客栈》/ 周杰伦 /《十二新作》；不存在暂停态或加载失败提示。
- 这关闭了本记录“切歌后尚未确认立即恢复 playing”的 Android 风险。剩余 iOS/鸿蒙媒体运行时验收由 B4-22 承接，不以本任务范围外的平台收口阻塞队列切歌交付。

## 完成结论

- `PlaybackQueueController` 的首尾循环、播放详情前后切歌、控制器回归和 Android 真实详情下一首均已完成；本任务范围内的功能、自动验证和当前 Android 真机验收齐备，状态更新为 `DONE`。
- iOS/鸿蒙媒体运行时与系统控件验收归属 B4-22，不阻塞共享队列切歌任务的交付。

### 2026-07-16 回归中断与恢复入口

- 已将 `ProcessingState.ready && !playing` 映射为 `paused`，并在 `play()` 调用后先发出 `playing` 快照，避免新曲加载完成的瞬时 `ready` 覆盖播放中的界面状态；对应单元测试已通过。
- 最新 Debug APK 已构建，但执行 `flutter install --debug -d R5CR70B7SMA` 时 Flutter 返回“`No supported devices found with id R5CR70B7SMA`”。这是调试真机当前未连接或未授权，不是构建或业务错误。
- 恢复时先确认 `adb devices -l` 中该设备为 `device`，再用受控 `kw` 音源重复“首曲播放 → 播放详情下一首”并确认第二曲立即为 `正在播放`、媒体焦点仍为 active。设备恢复前继续独立的自动切歌实现与单元验证。

### 2026-07-16 追加：控制器回归

- 当前 Flutter 回归 `flutter test test/playback_queue_test.dart test/player_controller_test.dart -r compact` 通过 12 项：首尾循环、完成后下一首、快速切歌旧请求隔离、URL 刷新/音质降级、进度恢复，以及后台 media command 的下一首均保持正确。
- 最新 Android 真机已重新连接且 B4-24 已用真实 LX 音源验证连续播放、媒体会话及系统播放/暂停键；播放详情的“下一首”可从已连接设备同一音源会话继续人工验收。任务仍为 `DOING`，不以控制器测试替代该详情页真机观察。
