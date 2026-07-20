# P7-01 `coralmusic://` 深链注册

- 阶段：Batch 8 / Phase 7
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：-

## 目标、范围与依赖

注册 `coralmusic://` 自定义 scheme，使 Android/iOS 可将应用链接交给 Flutter Router，已定义路由如 `/player`、`/search`、`/leaderboard` 继续由现有 `go_router` 处理。

不实现服务器 Universal/App Link，不接受任意外部数据写库，也不伪造 OpenHarmony manifest 字段；鸿蒙配置待真实 SDK/真机验证。

## 依据与实施记录

- Flutter 官方 Deep linking 文档说明 Router 接收 URL 后导航，当前工程已经使用 `MaterialApp.router` + `go_router`。
- 2026-07-20：开始 Android/iOS 原生 scheme 声明与真机启动验证。
- Android `MainActivity` 注册 `ACTION_VIEW + DEFAULT + BROWSABLE + coralmusic`，并显式启用 Flutter deep linking；iOS `Info.plist` 注册同名 `CFBundleURLScheme`。
- Android Debug APK 已构建、覆盖安装到 `SM-N986U / Android 13`；`adb shell am start -W -a android.intent.action.VIEW -d coralmusic:///player com.coral.music.mobile` 返回 `Status: ok` 并启动 `MainActivity`。
- 当前设备在锁屏/AOD 状态，无法读取 Flutter 页面无障碍树，因此不能将“已实际到达 `/player`”作为验收结果。
- 已执行 `plutil -lint ios/Runner/Info.plist`、`flutter analyze`、`git diff --check`；Android/iOS/鸿蒙的解锁真机路由验证、热启动回调和鸿蒙 manifest 配置待继续。

## 2026-07-20 OpenHarmony 声明补充

- 根据 OpenHarmony `module.json5` skill 的 URI 配置，新增独立 `ohos.want.action.viewData` / `entity.system.browsable` / `coralmusic` scheme skill，不修改桌面启动 skill。
- 该改动仅证明系统能力声明；Flutter engine 从 `Want.uri` 到 `go_router` 的冷/热启动分发必须在已签名鸿蒙真机上验证，尚未标记完成。
