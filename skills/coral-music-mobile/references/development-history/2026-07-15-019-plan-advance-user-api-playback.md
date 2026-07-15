# 计划修订：提前最小 User API 与播放调试闭环

- 类型：计划修订
- 状态：ACTIVE
- 负责人：Codex
- 创建时间：2026-07-15

## 背景与目标

用户要求将音源 User API 提前，以便尽快调试实际播放。原计划将完整 User API 放在 Phase 6、播放器放在 Phase 3；本修订将两者的最小可播放部分合并为下一个 Batch 4 任务。

## 桌面端基线

对照 `src/renderer-react/services/playerRuntime/musicUrlResolver.ts`、`services/userApiService.ts`、`common/types/user_api.d.ts`。桌面调用 User API 的 `musicUrl` 动作得到 URL，再交给播放器；`lyric`、`pic`、脚本列表、更新和同步不是首次播放所必需。

## 新的最小范围

1. 验证一个 Android 真机可播放的 HTTPS 音频 URL，建立 `AudioEngine`、播放/暂停/seek 和可观察状态。
2. 建立 `PlaybackResolver`，只接受在线 `Track`，先解析已有来源的 URL，再接入 User API `musicUrl` 结果。
3. 建立受限 `SourcePluginRunner` 可行性小样：仅执行 `musicUrl`，限制网络出口、超时、重定向、响应大小和返回 URL scheme；脚本不得拥有文件、原生桥、剪贴板或系统凭据访问权。
4. 将成功返回的 HTTPS URL 交给 `AudioEngine`，验证播放、暂停、seek 和单次失败重试。

## 明确不提前的内容

不提前实现 User API 文件/URL 导入、多个 API 管理、持久化、更新、`lyric`/`pic` 动作、来源能力设置、同步、OpenAPI 或商店版门控；它们仍属于 `P6-01`。不因调试需要关闭 TLS 校验或在 Dart 主隔离区执行不受限脚本。

## 依赖、验收与阻断

- 依赖 `P0-04` 音频/媒体小样与 `P0-09` 沙箱小样；Android 真机是本任务最小验收环境。
- 若三端兼容的受限脚本运行时不可用，任务只完成直连播放与 URL resolver，User API 部分保持 `BLOCKED`；不得以不安全实现标记完成。
- 验收：固定 URL 与受限 `musicUrl` 脚本各能在 Android 真机完成播放、暂停、seek；超时、非 HTTPS、超限响应和脚本异常不影响应用进程。

## 后续关联

关联 `B4-01`、`P0-04`、`P0-09`、`P3-01`、`P3-02`、`P6-01`。本修订不改变最终三端或商店合规范围。
