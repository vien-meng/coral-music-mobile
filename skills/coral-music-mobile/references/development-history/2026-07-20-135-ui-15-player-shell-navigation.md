# UI-15 播放器跳转应用壳红屏

- 阶段：高保真 UI / 应用路由
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 问题与范围

播放详情点击下载后，Snackbar 的“查看”使用 `push('/download')`。`/player` 位于应用壳外，`/download` 位于 `StatefulShellRoute` 内，继续压栈会重复构建壳导航并触发红屏。

播放器进入壳内目的地应使用 `go` 切换位置；设置页内部仍保留 `push`，因为它已经处于同一壳分支并需要系统返回栈。

## 实施与验证

- 2026-07-20：开始修复播放器“查看下载”和播放错误“去导入音源”两个同类壳外跳转，并补下载反馈入口回归。
- 2026-07-20：播放器 Snackbar“查看”由 `context.push('/download')` 改为 `context.go('/download')`；播放错误的“去导入音源”同步改为 `go('/setting/source')`。设置页内部同壳导航保持 `push`，保留系统返回行为。
- `test/app_shell_test.dart` 新增“播放详情下载 → 查看 → 下载管理”回归，并断言跳转后没有 Flutter 异常。
- 本次相关文件 `dart analyze` 与 `git diff --check` 通过；`flutter run -d R5CR70B7SMA --debug` 成功构建、安装并进入首帧。
- `flutter test test/app_shell_test.dart` 仍受工作区外 Flutter SDK cache 锁文件权限限制，自动提权服务返回 503；任务保持 `DOING`。
