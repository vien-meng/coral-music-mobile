# UI-02 首页发现与真实排行榜重构

- 阶段：高保真 UI 重构 / 第二任务
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标、范围与依赖

将默认 `/leaderboard` 从工具型榜单页改为设计稿“推荐”首页：顶部推荐/发现标签、春日渐变主推荐卡、功能快捷入口、精选歌单样式的榜单卡片、热门歌单横向卡片与真实榜单歌曲列表。保留 `LeaderboardController` 的五源切换、刷新、分页、错误重试、真实歌曲点击和“播放全部”。

依赖 UI-01 和既有 B2/B3 排行榜状态。不会把排行榜数据改为假数据，不创建新的网络请求，不处理播放器详情和歌词视觉。

## 对照行为与方案

- 设计稿首页视觉来自用户提供的 Coral Music 设计图；排行榜仍是桌面端/现有 Flutter 业务的默认发现数据入口。
- 来源选择从裸 `DropdownButton` 改为可见的柔和标签；榜单选择保持现有数据和切换行为。
- 无可用封面时使用纯 Flutter 渐变封面，网络封面失败可回退，不引入外部视觉资产。
- 窄屏纵向滚动，宽屏沿用共享 AppShell Rail；卡片宽度通过约束适配，不做固定截图尺寸。

## 计划验证与恢复入口

- 需要保留/新增默认首页、来源切换、播放全部与真实歌曲点击的 widget 测试。
- 当前 Flutter 分析受 Harmony SDK 环境变量缺失阻塞，代码完成后记录实际命令结果；不阻塞此任务继续实现。
- 实际修改：`lib/features/leaderboard/view/leaderboard_page.dart` 已改为真实数据驱动的推荐首页。它包含来源标签、渐变主推荐卡、横向榜单卡、真实歌曲圆角行、分页和错误卡；歌曲点击与“播放全部”仍调用既有队列/播放器。`test/app_shell_test.dart` 的来源切换测试已从下拉控件更新为可见来源标签。
- 重要决策：主推荐卡仅显示当前榜单/第一首真实封面；没有可实现的稿件按钮动作时，其“正在聆听”按钮保持禁用，避免添加无效交互。
- 已执行：Harmony Flutter 自带 Dart 的 `format`、`git diff --check`、`quick_validate.py skills/coral-music-mobile`，其中格式与 skill 校验通过。静态分析仍因缺少 `HOS_SDK_HOME` 被工具链阻断，任务继续保持 `DOING`。
- 补充验证：`dart analyze lib test` 已在当前 UI 合并状态通过；Flutter widget 测试与 Android 真机截图对照仍待执行。
- 恢复入口：`lib/features/leaderboard/view/leaderboard_page.dart`；环境可用后执行 `flutter analyze`、`flutter test test/app_shell_test.dart -r compact`。

## 关联

- 计划：`2026-07-16-064-plan-high-fidelity-ui.md`。
- 前置：`2026-07-16-065-ui-01-design-system-and-shell.md`。
- 后续：UI-03 搜索与详情。
