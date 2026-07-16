# B4-12 User API 音源导入与运行时管理

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

将单一临时调试脚本升级为可在当前会话中导入、验证、启用、切换、移除并查看能力的音源管理界面，确保被移除的当前音源无法继续取链。

不做内容：脚本安全持久化、系统文件选择器/URL 下载导入、iOS/鸿蒙运行时实现、商店版动态脚本门控和多脚本并发执行。

## 桌面端对照

- 桌面端 User API 支持来源脚本的导入、启停和能力识别；移动端复刻其业务行为，但只允许受限运行时和 HTTPS 网络出口。
- 对照源码：`coral-music-desktop` 的 User API 来源管理与 `musicUrl` 请求协议；移动端已有 Android `UserApiRunner.kt` 受限桥接。

## 实施方案与依赖

- Flutter 状态保存导入脚本、显示名称、声明的 `musicUrl` 来源和当前启用项；一次只激活一个脚本，以匹配现有单 WebView 受限运行时。
- `UserApiRunner` 增加 `clear` 平台边界；移除当前脚本时同步清空原生运行时和 Dart manifest，杜绝残留取链。
- 脚本仅驻留进程内存；不进入 SQLite、日志或崩溃诊断。安全持久化依赖后续三端 secure storage 适配。

## 当前进度

- 已确认原调用链仅支持 `load` 与 `resolveMusicUrl`；新增 `clear` 到 Dart `UserApiRunner`、Android `MethodChannel` 和 WebView 运行时，移除当前音源时取消在途请求并清空脚本、manifest 与来源能力。
- `UserApiDebugController` 现维护会话内脚本、名称、声明能力和当前启用项；新脚本验证失败时尝试恢复上一可用脚本，避免状态与原生运行时脱节。
- 设置页已改为“音源管理”：支持粘贴/HTTPS 地址导入、启用切换、取链与歌词能力展示、移除，以及保留 HTTPS 调试地址播放入口。
- 已新增 `test/user_api_debug_controller_test.dart`，覆盖导入、切换和移除当前音源。

## 修改与验证

- 修改：`lib/features/player/data/user_api_runner.dart`、`lib/features/player/state/user_api_debug_controller.dart`、`lib/features/player/view/user_api_debug_page.dart`、`android/app/src/main/kotlin/com/coral/music/mobile/UserApiRunner.kt`、`android/app/src/main/kotlin/com/coral/music/mobile/MainActivity.kt`。
- 验证通过：聚焦 `flutter test`、`flutter analyze --no-fatal-infos`、skill 格式校验、`flutter build apk --debug`。
- 真机：已有 SM-N986U / Android 13 的受限 `musicUrl` 取链/播放证据；本次管理 UI 的导入、切换、移除真机回归待补录。

## 验收与后续

- 验收：导入有效脚本后显示能力；切换脚本影响取链能力；移除当前脚本后取链返回“未支持”；无脚本内容写入持久库或日志。
- 关联计划：`2026-07-16-052-plan-b4-player-and-source-priority.md`；后续任务为在线取链与播放回归。

## 2026-07-16 进行中：脚本替换清理

- 原生运行时将把“导入替换、切换启用、移除”统一视作旧脚本失效：取消旧的 `musicUrl`/歌词请求，并将 WebView 导航到空白受限文档后仅重建桥接对象。
- 这样既避免旧结果回流，也避免已移除脚本继续驻留在活动 JavaScript 文档中；不把脚本写入磁盘或日志。
