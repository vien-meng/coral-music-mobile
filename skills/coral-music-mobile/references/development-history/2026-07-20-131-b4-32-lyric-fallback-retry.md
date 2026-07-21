# B4-32 歌词兜底与重试反馈

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 范围

修复酷我内置歌词失败后不再继续 User API 的断链，并让歌词页重试具备明确的加载和结果反馈。保留本地 LRC 最高优先级；增加仅本次应用会话有效的成功歌词缓存，不新增依赖或持久化表。

## 实施与验证

- `lyricProvider` 仍按本地 LRC → 酷我内置源 → User API 排序，但酷我 `AppFailure` 不再提前终止整条链；User API 仍会继续尝试，两者失败时保留合并后的可读错误。
- 在线成功歌词按稳定 `Track.id` 保留在当前 ProviderScope 会话，FIFO 限制 20 首；刷新或音源切换发生临时 `AppFailure` 时返回上次成功结果。缓存不落盘，离线持久歌词另立任务。
- 空本地 LRC 不再阻断在线源；在线返回无时间戳正文时清理 LRC 元数据和逐字标记，以普通可滚动歌词显示。
- 歌词页重试改用显式 `ref.refresh(...future)`；加载时显示“正在重新加载歌词”，空结果和失败均显示 SnackBar 反馈。
- `test/lyric_controller_test.dart` 增加酷我内置失败转 User API、刷新失败保留缓存；`test/lyric_timeline_test.dart` 增加无时间戳正文解析。
- 本次改动文件 `dart analyze` 无问题，`git diff --check` 通过。`flutter test test/lyric_controller_test.dart test/lyric_timeline_test.dart` 因工作区外 SDK 缓存授权服务返回 503 未执行，状态保持 `DOING`。
- 2026-07-20 后续 B4-35 已按桌面端职责边界将歌词从 User API 取链中分离，本记录中的“酷我内置源 -> User API”顺序不再是当前实现。记录：`2026-07-20-144-b4-35-independent-lyric-services.md`。
