# B4-20 User API HTTPS 地址导入

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

允许从 HTTPS URL 下载并验证 User API 脚本后直接启用，复用现有会话内音源管理。

不做：文件选择器导入、脚本持久化、重定向放行、HTTP/局域网 URL、商店版动态脚本门控。

## 安全方案与验收

- 复用已有 Dio 超时和错误映射；仅 HTTPS、有 host、最大 256 KiB、UTF-8 脚本，下载内容不记录日志或存入 SQLite。
- 验收：HTTP/超大脚本拒绝；HTTPS 脚本进入同一验证/启用/移除流程。

## 当前进度

- 新增流式 HTTPS 下载器，先检查地址、响应长度并在读取过程中限制 256 KiB，最后严格 UTF-8 解码；Dio 网络错误复用统一脱敏映射。
- 禁止重定向：避免已校验的 HTTPS 地址在下载时转向 HTTP 或未审计目标；3xx 继续按统一 HTTP 错误返回。
- 验证通过：`dart format lib/features/player/data/user_api_script_fetcher.dart` 和 `flutter test test/user_api_script_fetcher_test.dart -r compact`；重定向拒绝的真机网络回归待补。
- 音源管理页支持粘贴脚本或填写 HTTPS 地址，两条路径均进入原有 `importScript` 验证、启用、恢复旧脚本与移除流程。
- 已新增非 HTTPS 拒绝测试；聚焦 `flutter test`、`flutter analyze --no-fatal-infos` 通过。

## 风险与后续

- 未实现系统文件选择器与脚本安全持久化；地址导入只在当前会话保留脚本。真实 HTTPS 地址的 Android/iOS/鸿蒙真机回归待补录，任务保持 `DOING`。
