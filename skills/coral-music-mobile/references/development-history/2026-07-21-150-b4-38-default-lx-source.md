# B4-38 首次启动默认落雪音源

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 目标与边界

新安装的用户无需先进入音源管理即可使用在线播放。首次启动在没有用户保存音源时，加载已通过 Android 真机验证的公开 LX User API URL：

`https://raw.githubusercontent.com/pdone/lx-music-source/main/lx/latest.js`

已有的用户 URL 音源必须优先，默认源不得覆盖、替换或扩大 User API 的受限脚本网络权限。其他音源仍由用户在音源管理页自行导入。

## 验证要求

- 无保存来源时加载默认 URL 并保存为当前来源。
- 已保存来源时只恢复该来源，不请求默认 URL。
- 默认 URL 失败后控制器完成启动恢复，应用其余功能不被阻塞。

## 实施与验证

- `UserApiDebugController` 在启动恢复中先读取用户持久化来源；存在时保持原有恢复路径，不存在时通过现有 HTTPS URL 导入链路加载并保存“落雪音源”。没有内嵌或执行本地脚本，仍复用脚本大小限制、受限运行时和 HTTPS 校验。
- `UserApiScriptFetcher` 与 `UserApiSourcePreferences` 允许测试替身继承，未引入新的运行时抽象或依赖。
- `test/user_api_debug_controller_test.dart` 覆盖首次默认加载、用户来源优先和默认源下载失败三种场景。
- `dart format --output=none --set-exit-if-changed` 与定向 `dart analyze` 已通过。
- `flutter test test/user_api_debug_controller_test.dart` 首先因 Flutter SDK 位于工作区外无法锁定缓存而退出；按要求申请访问后，外部审批服务仍返回 HTTP 503。待审批恢复后执行定向 Flutter 测试；因此任务保持 `DOING`。
