# B4-30 User API HTTPS 来源恢复

- 阶段：Batch 4 / Phase 6
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：2026-07-20

## 目标、范围与安全边界

让明确导入的 HTTPS User API 在跨重启后恢复启用，但不持久化动态脚本内容。只保存来源 URL 与显示名称；每次启动都经既有大小、UTF-8、HTTPS 和运行时校验重新获取脚本。

本任务不持久化本地文件/粘贴脚本，不扩展脚本网络权限，不建设服务器同步或绕过商店门控。

## 实际修改与验证

- 新增 `UserApiSourcePreferences`，使用系统安全存储保存当前 HTTPS 来源的名称和地址；损坏数据或非 HTTPS 地址直接忽略。
- Controller 启动后恢复地址并调用既有 `importUrl` 重新下载/加载；切换 HTTPS 来源更新记录，启用本地会话脚本或移除当前来源会清除记录。
- `dart format`、`flutter analyze` 和 `git diff --check` 通过。真实 iOS/鸿蒙跨重启与商店政策验收仍待三端阶段。
