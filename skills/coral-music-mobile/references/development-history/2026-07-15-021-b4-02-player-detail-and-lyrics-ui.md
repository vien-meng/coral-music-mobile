# B4-02 播放详情与歌词阅读界面

- 阶段：Batch 4 / Phase 3
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-15
- 完成时间：2026-07-15

## 目标、范围、不做内容与依赖

在已有迷你播放栏和最小 `PlayerController` 上补齐可进入的播放详情页，并提供清晰的歌词阅读入口。页面采用珊瑚主题、沉浸式专辑卡片、大进度条和大字号歌词阅读层级；参考用户提供的 QQ 音乐移动端截图中的信息组织与留白，不复制其图标、文案、专辑素材或视觉资产。

本任务只实现详情/歌词的展示结构、当前歌曲信息、播放暂停与 seek。依赖 B2-05、B2-06、B4-01；不实现歌词请求、LRC 解析、逐字高亮、翻译/罗马音、队列前后切歌、收藏、音质选择、后台媒体控制或音效。

## 桌面端基线与确认行为

对照 `coral-music-desktop/src/renderer-react/services/desktopLyricService.ts`、`coral-music-desktop/src/lyric-react/App.tsx`、`coral-music-desktop/src/lyric-react/services/lyricTimeline.ts`。桌面端将歌曲元信息、原文、翻译、罗马音和逐字歌词推送至独立歌词渲染器；移动端以应用内详情页承载同一用户目标，先保留数据未就绪时的明确空态。

## 实施方案与平台差异

- 增加根路由 `/player`，从迷你播放栏进入，避免详情页继续显示壳层底部导航与第二个迷你播放栏。
- `PlayerDetailPage` 仅消费现有 `playerProvider`、`playbackQueueProvider`：正在播放歌曲优先，否则显示队列当前歌曲；不新增数据层。
- 专辑封面使用现有 `Track.coverUri`，不可用时显示珊瑚主题唱片占位；进度条复用现有 `PlayerController.seek`。
- 歌词页显示歌曲上下文与数据未接入说明。后续 `P3-06` 接入 `LyricPayload` 后替换空态，不改变详情页入口或播放控制。

## 数据变更、风险与恢复入口

无持久化和领域模型变更。歌词没有被伪造成真实内容；播放详情仍受 B4-01 Android 真机解锁后的实际播放/seek 验收约束。恢复入口为 `lib/features/player/view/player_detail_page.dart`、`mini_player.dart`、`app_router.dart` 和本记录。

## 实际修改与完成内容

- `lib/features/player/view/player_detail_page.dart`：新增独立播放详情根页面。使用珊瑚色渐变、唱片感圆形封面、歌曲元信息、进度、播放/暂停与状态反馈；点击右上角切换到歌词阅读态。
- `lib/features/player/view/mini_player.dart`：迷你播放栏点击进入 `/player`，保留原播放/暂停按钮行为。
- `lib/app/app_router.dart`：详情页位于应用壳之外，因此不会叠加底部导航或第二个迷你播放栏。
- `test/app_shell_test.dart`：增加“播放全部 → 迷你播放器 → 播放详情 → 歌词空态”的 Widget 回归。
- `android/app/build.gradle`、`android/gradle.properties`：为 B4-01 引入的音频依赖完成 API 24 与 Kotlin 目标兼容配置；详见 B4-01 的同日构建兼容性记录。

## 重要决策与调整

- 参考图只借鉴移动端信息层级、留白、沉浸式封面和歌词阅读氛围，不复用 QQ 音乐的图标、文案、视觉资产或页面细节。
- 不在没有 `LyricPayload`、在线歌词服务或本地 LRC 导入的情况下展示示例歌词；空态明确说明后续数据接入和本地 LRC 优先规则。
- 不提前增加收藏、上一首/下一首、音质或队列抽屉等没有对应状态/业务实现的按钮，避免误导用户。

## 验证结果

- `dart format --output=none --set-exit-if-changed lib test`：通过，45 个文件均已格式化。
- `flutter analyze`：通过，无诊断。
- `flutter test`：通过，20 个测试通过；3 个显式标记为需 `CORAL_LIVE_TEST=true` 的在线冒烟测试跳过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- `flutter build hap --debug`：通过，产物为 `ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`。
- `python3 /Users/vien.meng/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/coral-music-mobile`：通过，返回 `Skill is valid!`。

## 未完成项、风险与下一步

- B4-01 的 Android 真机实际出声、暂停、seek 和 User API 取链仍因设备锁屏等待用户解锁后验收；本 UI 任务不绕过设备锁屏。
- 下一项按 P3-06 接入 `LyricPayload`、LRC 解析/时间轴与本地优先，再将当前歌词空态替换为真实滚动歌词。

## 关联

关联计划修订 019、B2-05、B2-06、B4-01、P1-03、P3-05、P3-06、功能矩阵“播放详情”“歌词呈现”。

## 2026-07-17 后续能力 Android 真机回归

- 播放详情已由后续 B4 任务接入真实 SQLite 收藏。Samsung SM-N986U / Android 13 的后台真实播放会话回前台后，点击顶部收藏按钮由轮廓心形切换为实心心形；系统媒体会话仍为 `PLAYING`，收藏写入不打断播放。
- 此验证覆盖页面收藏动作接线与播放独立性；收藏列表展示与跨重启读取属于列表批次验收。
