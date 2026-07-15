# 珊瑚音乐移动端业务开发计划记录

- 类型：计划
- 编号：PLAN-2026-07-15-01
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-15
- 完成时间：2026-07-15

## 目标与范围

以桌面端为行为基线，按“排行榜真实数据、播放队列、在线播放、搜索/歌单、本地媒体、下载/WebDAV、高级能力”实施 Flutter 三端移动客户端。环境收口暂缓，共享 Dart 业务优先使用 Android 验证。

## 方案与决策

- 以 `../development-plan.md` 为当前状态总表，以 `../feature-parity.md` 为功能验收矩阵。
- 每个计划和任务使用独立历史文件，任务开始前标记 `DOING`，验证后才能标记 `DONE`。
- 第一条纵向切片锁定为酷我排行榜、歌曲列表、播放队列和迷你播放栏。
- 依赖按真实调用方加入，不批量创建平台桥接或数据库空壳。

## 桌面端基线

- `src/renderer-react/app/routeConfig.tsx`
- `src/renderer-react/stores/domains/leaderboardStore.ts`
- `src/renderer-react/features/leaderboard/LeaderboardRoutePanel.tsx`
- `src/renderer-react/services/onlineMusicService.ts`

## 验证、风险与后续

- 本记录不涉及代码验证。
- iOS Runtime、鸿蒙签名和三端真机仍是平台验收阻塞，不阻塞当前共享业务开发。
- 后续按 `B1-01` 至 `B2-06` 顺序执行。

