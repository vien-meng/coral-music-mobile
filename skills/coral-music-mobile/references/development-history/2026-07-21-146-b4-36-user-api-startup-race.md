# B4-36 启动音源恢复与平台切换隔离

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 根因与目标

应用启动时，已保存 User API 的 WebView 重载与最近在线歌曲的取链并发执行。重载会暂时清空运行时；用户此时切换发现页音乐平台并点歌，会将该竞态误认为平台切换使音源失效，且必须手动刷新音源才能恢复。

音乐平台仅控制目录数据，不能清理、替换或使 User API 运行时失效。启动恢复必须是单例操作，所有在线取链和上次播放恢复都需等待它结束。

## 验证要求

- 多次请求启动恢复只复用同一个 Future，不触发第二次脚本加载。
- 在线取链在启动恢复完成前不调用运行时，完成后正常取链。
- 切换目录平台不访问 User API 控制器或运行时。

## 实施与验证

- `UserApiDebugController` 在构造时只创建一次持久化来源恢复 Future；后续 `restorePersisted()` 只返回该 Future，不会启动第二个 WebView 重载。
- `PlaybackResolver` 持有该启动 Future，并仅在在线歌曲取链前等待它；本地、下载和 WebDAV 仍保持原有直连路径。
- 应用恢复上次播放前等待同一个 Future。发现页的目录平台切换仍仅调用 `LeaderboardController.selectSource()`，不接触 User API 控制器或运行时。
- `test/playback_resolver_test.dart` 增加恢复未完成时不调用 `resolveMusicUrl` 的回归用例。
- `dart format`、定向 `dart analyze` 和 `git diff --check` 通过。
- `flutter test test/playback_resolver_test.dart` 未能启动：Flutter SDK 缓存锁位于工作区外；按要求申请访问时外部审批服务返回 HTTP 503。待服务恢复后运行该用例与 Android 真机切换平台回归，任务保持 `DOING`。
