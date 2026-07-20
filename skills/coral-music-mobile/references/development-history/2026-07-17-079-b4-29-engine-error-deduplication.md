# B4-29 音频引擎重复错误去重

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-17
- 完成时间：未完成

## 目标与范围

保证一次音频加载失败只触发一次 URL 刷新、音质降级或队列跳歌决策。覆盖 `just_audio` 同时通过 `load()` Future 抛错及 `errorStream` 发出错误快照的真实行为。

不做内容：重试退避、跨来源换源、持久失败记录、UI 级重复按钮拦截。

## 根因、桌面基线与方案

- 根因：`PlayerController.playTrack()` 的 `await _engine.load()` 错误分支和 `_onSnapshot()` 的错误分支都会调用 `_handleEngineFailure()`；现有“已刷新质量”集合只能防重复刷新，第二次处理仍可能直接消耗音质降级或跳过下一曲。
- 桌面基线：一次播放请求的失败只能推进一次恢复策略。移动端在控制器按 `Track.id + AudioQuality` 去重；开始真实的同质量刷新尝试时再释放该标记，让第二次加载失败可合法进入降级链。

## 验收与风险

- 验收：同一质量同一次失败同时来自快照和 Future 时，只加载一次刷新 URL；刷新后的独立失败仍能继续降级/跳歌。
- 风险：音频平台可能在新加载已开始后才补发旧错误；现有 `_playRequest` 已隔离旧请求，本任务不放宽该边界。

## 2026-07-17 实施与验证

- `PlayerController` 新增按 `Track.id + AudioQuality` 记录的本次引擎错误集合；同一加载尝试的 Future 异常与错误快照只允许第一条进入恢复策略。
- 真正开始同质量的 `refreshUrl` 尝试时会释放该键，因此刷新后的独立错误仍会按原规则进入下一档质量或队列跳过。用户手动点歌时同样清除该曲的失败/刷新/去重状态。
- 引擎加载错误现在使用 User API 实际返回的质量，而不是用户请求但已被脚本降档的质量；例如请求 SQ 却得到 320k 时，失败会从真实 320k 往下处理，不会错误重复请求 SQ。
- 验证：`dart format`、`flutter analyze --no-fatal-infos`、`flutter build ios --no-codesign` 与 `git diff --check` 通过。受控双通道错误的单测与 Android 真机失败流留待后续集中回归。

## 当前状态

- 状态保持 `DOING`，待把“Future 抛错 + errorStream 同次错误”写入受控假引擎用例，并在真机过期 URL 场景确认不会提前跳过。
