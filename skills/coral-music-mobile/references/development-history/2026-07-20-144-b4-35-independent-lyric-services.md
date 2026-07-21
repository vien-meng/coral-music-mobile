# B4-35 独立歌词服务链路

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 根因

移动端歌词链路是本地 LRC -> Android 酷我通道 -> User API。User API manifest 只声明 `musicUrl` 时，Dart 仍调用 `resolveLyric`，最终把脚本返回的 `action not support` 展示给用户；这与桌面端内置 `musicSdk` 的来源歌词服务不一致。

## 目标

- 歌词获取不依赖 User API 是否支持 `lyric` action。
- 按桌面端思路优先调用内置来源歌词服务；酷我失败后继续走独立的公共歌词搜索兜底。
- 失败时隐藏脚本内部错误，保留可读重试反馈；不承诺任何服务覆盖全部歌曲。

## 验证要求

- 仅声明 `musicUrl` 的 User API 不再收到 `lyric` 请求。
- 独立歌词服务返回同步或纯文本歌词都能归一化为 `LyricPayload`。
- 内置来源失败不会阻断后续歌词兜底和手动重试。

## 实施与验证

- 对照桌面端 `onlineMediaService`、内置 `musicSdk.getLyric` 和关键词候选搜索，移动端 `lyricProvider` 已移除 `userApiRunnerProvider` 依赖，顺序调整为本地 LRC -> 内置来源服务 -> LRCLIB 独立歌词搜索 -> 会话缓存。
- `MethodChannelUserApiRunner.resolveLyric()` 只在 manifest 明确声明对应来源的 `lyric` action 时才允许调用，兼容入口不会再对仅支持 `musicUrl` 的插件发送歌词请求。
- Android 酷我内置通道保留桌面端 `newlyric.lrc` 压缩协议，并在响应格式变化时回退到桌面代码曾使用的 HTTPS `songinfoandlrc` JSON 端点。
- LRCLIB 先按歌名、歌手、专辑和时长精确匹配；404 后继续关键词候选搜索，优先同歌手和同步歌词，找不到时返回可重试空态，不暴露第三方或脚本内部错误。
- `test/user_api_runner_test.dart` 覆盖 `musicUrl`-only manifest 不请求歌词；`test/lyric_controller_test.dart` 覆盖酷我失败后独立服务兜底和成功歌词缓存；`test/lrclib_lyric_service_test.dart` 覆盖同步/纯文本解析及候选选择。
- 相关 `dart format`、定向 `dart analyze` 和 `git diff --check` 通过。
- `dart test` 不适用于仅依赖 `flutter_test` 的本项目；`flutter test` 和 Android Kotlin 编译因外部审批服务返回 HTTP 503 未启动，任务保持 `DOING`。
