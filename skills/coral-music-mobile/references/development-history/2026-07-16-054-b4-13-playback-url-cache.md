# B4-13 在线取链缓存与过期刷新重试

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

为在线歌曲的 `musicUrl` 解析增加短时内存缓存；音频加载或播放引擎报错时，对同一歌曲只强制重新取链一次，再进入既有失效音源跳过逻辑。

不做内容：跨重启持久 URL 缓存、服务端到期时间解析、跨来源换源、音质降级策略和本地/WebDAV URL 解析。

## 桌面端对照

- 桌面播放流程会缓存已解析的播放地址，并在临时地址失效时重新取链；本切片保持移动端 HTTPS 与受限 User API 边界。
- 对照路径：`coral-music-desktop` 播放地址解析与播放失败重试流程；移动端对应 `PlaybackResolver`、`PlayerController`。

## 实施方案、依赖与验收

- `PlaybackResolver` 以歌曲稳定 ID 与音质为键保存 15 分钟内存缓存，并提供定点失效接口。
- `PlayerController` 将地址解析错误与音频加载错误分开处理；后者清缓存并仅重试一次，避免死循环。
- 验收：相同歌曲/音质重复解析只调用一次运行时；强制刷新再次调用；加载失败最多重新取链一次；已有自动跳过行为不回退。

## 当前进度

- `PlaybackResolver` 已以歌曲稳定 ID 与音质为键缓存 15 分钟 HTTPS URL；`forceRefresh` 和 `invalidate` 不新增持久数据库或网络依赖。
- `PlayerController` 已将取链失败和音频引擎失败分开处理：只有引擎失败会清掉当前缓存并重新取链一次；第二次失败才进入既有跳过逻辑。
- 已新增 `test/playback_resolver_test.dart`，并扩展 `test/player_controller_test.dart` 覆盖加载失败后的单次刷新重试。

## 修改与验证

- 修改：`lib/features/player/data/playback_resolver.dart`、`lib/features/player/state/player_controller.dart`、对应测试。
- 验证通过：聚焦 `flutter test`、`flutter analyze --no-fatal-infos`、skill 格式校验、`flutter build apk --debug`。
- 真机：本次临时 URL 过期重取链回归待在 Android/iOS/鸿蒙设备补录，因此任务保持 `DOING`。

## 关联

- 依赖：B4-01、B4-12。
- 后续：播放进度恢复、后台媒体与歌词数据。

## 2026-07-16 追加：非在线来源直连

- `PlaybackResolver` 对本地、下载和 WebDAV 的 `Track.localUri` 直接返回，不查询 User API、不写在线 URL 缓存，也不参与在线音质降级。
- `uses non-online URIs without invoking User API` 覆盖三类来源的共享边界；没有地址时返回可读的“缺少播放地址”错误。
- 关联功能矩阵：四类来源 P0；本地文件导入和 WebDAV 发现仍属于后续 B5/B6 范围。

## 2026-07-17 音源运行时变更清理（DONE for shared cache boundary）

- 缓存键只含歌曲和音质，不能跨 User API 脚本复用。`PlaybackResolver.clear()` 现由音源管理器在成功导入、启用或清除当前脚本后调用；失败操作不会影响旧缓存和正在播放的已加载音频。
- 回归由 `test/user_api_debug_controller_test.dart` 的 `clears cached URLs after the active source changes` 覆盖；同一在线歌曲在脚本变更后重新执行 `resolveMusicUrl`。聚焦测试 3 项、静态分析和 diff 检查通过。

## 2026-07-17 实际质量随缓存保留（DONE for shared cache payload）

- 缓存条目由单一 URL 改为 `ResolvedPlaybackUrl`，同时保存音源实际返回的质量 type；命中缓存与首次取链都会向播放器提供同一准确质量，不会仅首次加载显示 HQ、缓存重播又错误回到请求的 SQ。
- 缓存键仍为“歌曲 + 请求质量”，因此不改变用户选择质量、URL 刷新或失败降档策略。协议与控制器回归、Android Debug APK 构建均见 B4-10 同日记录。

## 2026-07-17 请求质量与实际质量别名失效（DOING）

- 音源可对 SQ 请求实际返回 HQ。缓存正确保留在“请求 SQ”键下，但播放失败时控制器会按实际 HQ 调用 `invalidate`，旧 SQ 键可能残留并在用户再次选择 SQ 时返回过期地址。
- 将让定点失效在移除请求质量键之外，同时移除同曲且 `ResolvedPlaybackUrl.quality` 等于目标质量的别名缓存；不改变正常命中策略或跨曲目边界。

## 2026-07-17 请求质量与实际质量别名失效（DONE for shared cache）

- `PlaybackResolver.invalidate()` 现在先移除正常的“歌曲 + 请求质量”键，再移除同一稳定曲目下实际返回质量匹配的缓存条目。只有音源明确返回 `type` 时才存在别名，正常同质 URL 的行为不变。
- 这样当请求 SQ 实际得到 HQ 且 HQ 流失败时，刷新/降级不会留下 SQ 键下的旧 HQ 地址；不跨曲目删除，不持久化 URL。
- 按当前业务优先节奏未单独运行缓存用例；将在下一次播放器聚合测试加入“SQ 请求返回 HQ 后按 HQ 失效”的断言。
