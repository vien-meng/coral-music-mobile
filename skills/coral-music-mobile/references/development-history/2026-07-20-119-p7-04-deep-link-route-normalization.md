# P7-04 深链路由归一化

- 阶段：Phase 7
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：2026-07-20

## 目标、范围与依赖

让 `coralmusic:///player` 与 `coralmusic://player` 都归一化到 Flutter 的 `/player` 路由，避免不同分享方的 URI 写法造成落点失败。

依赖已有三端协议注册与 `go_router`。不新增深链参数协议、远程指令或服务器跳转。

## 实施记录

- 2026-07-20：开始在路由入口修正自定义 scheme 的 host/path 映射；未注册的路径应回落默认页面而不是形成循环重定向。
- 2026-07-20：`go_router` 入口统一识别协议路径与主机名写法，支持播放器及九个已有主页面；未知自定义深链安全回落排行榜，普通应用路由不重定向。
- 验证：`dart format`、`flutter test test/app_router_test.dart`、`flutter analyze` 与 `git diff --check` 均通过。
- 2026-07-20：重新构建并安装 Android Debug 包；`adb shell am start -W -a android.intent.action.VIEW -d coralmusic://player com.coral.music.mobile` 返回 `Status: ok`，系统启动 `MainActivity`。Flutter 页面可视落点仍待设备解锁后确认。

## 验收与下一步

- Android/iOS/Harmony 的系统回调和 Android 真机完整落点回归仍待 Phase 7 设备验收。
- 关联：`P7-01`、`P7-02`。
