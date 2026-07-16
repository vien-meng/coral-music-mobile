# B4-23 快速切歌旧请求隔离

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标、范围、不做内容与依赖

确保快速点选多首在线歌曲时，较早的异步取链、加载成功或失败不会覆盖最后一次点选的曲目和播放状态。

范围：在 `PlayerController` 为每次播放意图建立单调请求标识，并在取链、加载、seek、自动播放及失败处理的异步边界校验。依赖 B4-01、B4-13、B4-19。

不做：取消 User API 网络请求、跨进程队列持久化或跨来源换源；运行时没有取消 API 时，旧请求只会被安全忽略。

## 桌面端基线与确认行为

桌面播放切换以最后一次用户选择为准。移动端排行榜/搜索已经有旧响应隔离，但播放器此前没有同类保护，因此一个慢取链可能在用户选择下一首后重新加载旧曲。

## 实施方案、数据变更与平台差异

- `PlayerController` 持有只在内存存在的播放请求序号；新请求会使旧请求失效。
- 切换不同曲目时仅在旧引擎已进入可播放状态后停止它，避免“尚在取链”的状态意外初始化后台媒体服务；每个异步返回点均确认仍是当前请求，再触发下一步或上报错误。
- 不新增数据库、平台通道或依赖；三端共享同一 Dart 行为。

## 验证、风险与恢复入口

- 新增延迟 User API 的控制器测试：先发起第一首，再发起第二首并先完成第二首取链，最后完成第一首；最终只能加载第二首。
- 后续在 Android 真机用两个不同延迟的真实音源复验。恢复入口：`PlayerController.playTrack` 的请求序号与该测试。
- 关联：P3-02、P3-03、功能矩阵“在线播放/队列”。

## 实际修改与验证

- 修改：`lib/features/player/state/player_controller.dart` 为普通播放和 HTTPS 调试播放共享单调请求序号；旧请求在取链、加载、seek、播放和失败映射前均会退出。
- 修改：`test/player_controller_test.dart` 新增 `ignores a stale playback URL after the user selects another track`，使用两个可控延迟的 User API 响应复现先慢后快的切歌。
- 验证通过：`dart format` 及 `flutter test test/player_controller_test.dart -r compact`（9 项）。
- 真机：双延迟真实音源的 Android/iOS/鸿蒙验证待补，因此任务维持 `DOING`。
