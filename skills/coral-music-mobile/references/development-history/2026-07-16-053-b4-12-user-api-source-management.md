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
- 实际修改：`android/app/src/main/kotlin/com/coral/music/mobile/UserApiRunner.kt` 的 `load`、`clear`、`dispose` 共用在途请求取消逻辑；`clear` 重置 WebView 文档。验证通过：`flutter build apk --debug`，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。切换/移除脚本的 Android 真机回归仍待补录。
- 输入边界：Dart 和 Android 原生运行时均将纯空白脚本视为无效，立即返回既有“音源脚本为空或超过大小限制”错误，不启动 WebView 初始化超时。
- 验证通过：`test/user_api_runner_test.dart` 使用 mock MethodChannel 确认空白脚本不会调用原生运行时；`flutter test test/user_api_runner_test.dart -r compact` 通过。

## 2026-07-17 会话内音源管理导航修复

- 真机发现“我的 → 设置/音源管理”此前使用 `context.go('/setting')` 替换了路由，系统返回会结束 Activity；由于脚本刻意只驻留会话内存，重新启动后音源会被正确清除，却使同一会话导入后返回搜索不符合移动端预期。
- `MorePage` 的三个设置入口改为 `context.push('/setting')`；底栏主页面及其它“我的”快捷入口仍保持 `go`，不改变 Tab 的替换导航行为。
- 新增 `test/more_page_test.dart` 覆盖“打开设置 → router.pop → 返回我的”；测试、相关 Dart 分析和 diff 检查通过。
- Samsung SM-N986U / Android 13 覆盖安装后，真实执行“我的 → 设置 → 系统返回”，前台仍为 `com.coral.music.mobile.MainActivity`，界面回到“我的”。随后同一会话重新导入用户指定 LX URL，能力卡正确显示 `kw、kg、tx、wy、mg、local`，证明返回不会清空会话内运行时。

## 2026-07-17 音源切换与取链缓存边界（DOING）

- 审计发现 `PlaybackResolver` 以“歌曲稳定 ID + 音质”缓存 URL 15 分钟，却不了解当前 User API 脚本；成功导入、启用或移除脚本后，同一曲目可能继续使用前一个脚本生成的旧 URL。
- 这直接违反音源管理的“切换立即影响取链”行为，且会让用户误以为新脚本未生效。修订范围仅为成功切换运行时后的内存 URL 缓存失效；不持久化脚本、URL 或凭据，也不打断正在播放的已加载音频。

## 2026-07-17 音源切换与取链缓存边界（DONE for shared runtime）

- `PlaybackResolver` 新增仅清空会话内缓存的 `clear()`；`UserApiDebugController` 在新脚本成功导入并启用、切换启用成功，或移除当前运行时成功后调用它。验证失败会恢复旧运行时且不清缓存。
- 这样后续点播同一歌曲必定向当前启用脚本重新取链；已经被 `AudioPlayer` 加载的当前曲目不会被中途停止。脚本本身仍只在进程内存保存。
- 新增 `clears cached URLs after the active source changes`：同一首酷我歌曲先通过版本一脚本解析、成功导入版本二后再次解析，确认 `UserApiRunner.resolveMusicUrl` 被调用两次，而不是命中旧 15 分钟 URL。`flutter test test/user_api_debug_controller_test.dart -r compact` 3 项通过，`flutter analyze --no-fatal-infos` 与 `git diff --check` 通过。

## 2026-07-17 URL 音源刷新与回退（DOING）

- URL 导入的真实 LX 脚本可能更新；此前用户只能移除后重新粘贴 URL，且加载更新失败后没有面向“原脚本仍可用”的专门恢复路径。
- 将为具有 `originUrl` 的音源增加原地址刷新：先下载，再在原生受限运行时验证；成功才替换脚本、公开详情和能力，并清空会话 URL 缓存。下载或运行时验证失败时立即重新加载旧脚本，保留原音源卡和启用状态。
- 不写入脚本磁盘、不做后台自动更新，也不刷新没有 HTTPS 来源地址的手动粘贴脚本。

## 2026-07-17 URL 音源刷新与回退（共享实现完成）

- `UserApiDebugController.refresh()` 仅接受当前启用且存在 HTTPS `originUrl` 的来源：下载新脚本 → 受限运行时 `load`/能力验证 → 以原 ID 替换脚本、声明详情和能力 → 清空播放 URL 缓存。
- 下载、解析或脚本验证失败时 `_restore(previous)` 重新加载旧脚本；原音源卡、启用状态和正在播放的已加载媒体均保留。用户手动命名不会被新脚本的 metadata 覆盖。
- 音源详情卡为可刷新来源显示“从原地址刷新音源”按钮；手动粘贴且无来源 URL 的脚本不显示该操作。
- 验证：`dart format`、`flutter analyze --no-fatal-infos`、`flutter build ios --no-codesign` 与 `git diff --check` 通过。真实 LX 脚本刷新/失败回退的 Android 真机场景待后续集中验收。

## 2026-07-17 音源刷新后的歌词失效（DONE for shared state）

- 发现 URL 音源刷新会保持同一个 source ID；原歌词 Provider 仅监听 active ID，因此会继续命中旧歌词 Provider 缓存，即使脚本已经更新。
- `UserApiDebugState` 新增仅进程内的 `runtimeRevision`，在导入、启用、刷新成功或移除当前运行时后递增。播放 URL 缓存仍由既有 `PlaybackResolver.clear()` 处理。
- `lyricProvider` 同时监听该 revision，因而当前曲目的歌词会在音源刷新后重新通过已启用脚本获取；不把歌词、脚本或凭据写入数据库。
# 2026-07-20 本地脚本文件导入（DOING）

- 桌面端支持导入脚本文件，移动端当前仅有 HTTPS URL 与开发粘贴框。本轮补系统文件选择的 `.js` 导入，复用同一受限运行时；不持久化脚本、不允许非 UTF-8 或超过 256 KiB 内容。
- 已通过 `file_picker` 提供 `.js` 文件选择；读取字节先在 Dart 边界检查 256 KiB 与 UTF-8，成功后才调用既有 `importScript`、WebView 受限运行时和能力解析。脚本继续仅驻留会话内存。
- 新增控制器回归覆盖字节脚本导入和超限拒绝；`flutter analyze`、`flutter test test/user_api_debug_controller_test.dart test/user_api_script_fetcher_test.dart` 及 `git diff --check` 通过。Android/iOS/鸿蒙文件选择器真机回归仍待平台阶段。
