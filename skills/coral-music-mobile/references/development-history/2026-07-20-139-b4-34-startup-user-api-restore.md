# B4-34 启动时恢复音源

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 目标与根因

应用启动时立即恢复已持久化的 HTTPS 音源，不再依赖用户先进入“设置 → 音源管理”。

`UserApiDebugController` 构造时已有 `restorePersisted()`，但对应 Provider 此前只由音源管理页面读取，所以控制器在首次进入该页面前不会创建。应用根启动组件应主动创建现有 Provider，不复制恢复或加载逻辑。

## 验证要求

- 启动应用但不进入设置页时，`userApiDebugProvider` 已创建。
- 无已保存音源或恢复失败时不阻断应用启动。
- Android 真机启动后可直接播放已保存音源支持的在线歌曲。

## 实施与验证

- 应用根启动组件在 `initState()` 创建 `userApiDebugProvider`；控制器构造函数继续唯一负责 `restorePersisted()`，没有重复恢复调用。
- `test/app_shell_test.dart` 增加启动后 Provider 已创建的回归检查。
- `dart format`、针对性 `dart analyze` 和 `git diff --check` 通过。
- Samsung SM-N986U / Android 13 冷启动时，在未进入设置页且无点击前已出现 `UserApiRunner.load`、受限 WebView 创建和 `CoralUserApi request status=200`；随后在线 FLAC 成功进入 ExoPlayer 解码，确认保存音源可直接使用。
- `flutter test test/app_shell_test.dart` 被工作区外 Flutter SDK 缓存锁权限拦截；提权重试因审批服务返回 503 未执行，因此任务保持 `DOING`。
