# B4-10 当前曲目音质选择

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标、范围、不做内容与依赖

在播放详情显示当前可用音质并允许选择；切换后必须以选中音质重新通过 User API 取链并加载，而非只更新显示状态。

依赖 B1-04、B4-01、B4-02。不实现缺失音质自动降级、跨来源换源、URL 缓存、全局音质设置或本地/WebDAV 音质链；它们需要来源与缓存任务。

## 桌面端基线与确认行为

对照桌面端 `playerStore` 的播放音质和 User API `musicUrl` 质量参数。桌面端将质量传入统一运行时；移动端沿用 `AudioQuality` 与受限 User API 的既有参数映射，确保同一选择影响真实取链。

## 实施方案、关键接口、数据与平台差异

- `PlaybackResolver.resolve` 接受可选显式音质；无显式选择时保持现有“曲目最高可用、无声明则 128k”规则。
- `PlayerState` 保存本次加载实际使用的音质；`PlayerController.setQuality` 重新走 `playTrack`。
- 播放详情使用标准 `PopupMenuButton` 展示曲目声明的可用质量；不包含本地或 WebDAV 伪选项。

## 验收、风险与恢复入口

- 批次收口时验证质量参数传递、切换后重新加载和曲目不支持质量时的安全拒绝；Android 真机需用支持多质量的受控 User API 脚本复验。
- 实际修改和验证结果将在完成时补充。

关联 P3-02、功能矩阵“音质”；后续为降级和换源。

## 当日实施进度

- `PlaybackResolver` 已接受显式音质，播放器状态保存实际选择；详情页仅对曲目声明的质量展示菜单，选择后重新取链加载。
- 音质切换会携带当前进度、倍速、音量及播放/暂停意图：暂停时只预加载并保持暂停，播放中则在同一有效进度继续播放。在线取链失败后的刷新和降级重试也保持同一意图。
- 验证入口：`test/player_controller_test.dart` 的 `keeps a paused track position and player settings when changing quality`；Android 多音质音源的真机验收仍待补，因此任务维持 `DOING`。

## 2026-07-17 默认 SQ 调整（DOING）

- 产品要求将在线播放默认质量从 `128k` 改为 SQ。初始实现错误地把 SQ 映射为既有 `AudioQuality.high320k`/User API `320k` 参数。
- 同时修改 `PlayerState`、`PlayerController` 与 `PlaybackResolver` 的无显式音质默认值，确保 UI、实际取链和 URL 缓存键保持一致；不影响用户手动选择质量和 B4-19 的降级链。

## 2026-07-17 实施与验证

- 当时新增的 `defaults online playback to SQ when 320k is declared` 只证明了错误映射，已在下方修订中替换；Android Debug APK 构建通过，但该验证不得作为 SQ 行为证据。

## 2026-07-17 SQ 定义修订（DOING）

- 产品澄清：`HQ = 320k`，`SQ = FLAC`，其上依次为 Hi-Res、母带等。此前播放页的 `SQ · 320 kbps` 为错误文案，不应保留。
- 修订：默认显式请求 `AudioQuality.flac`/User API `flac`；有 SQ 时即使同时声明更高质量也保持 SQ 默认；没有 SQ 时才按已声明档位选择最高可用项。界面改为 `SQ · FLAC 无损`、`HQ · 320 kbps`、`Hi-Res 24bit` 等正确名称。

## 2026-07-17 Android 真机多音质切换回归

- Samsung SM-N986U / Android 13 使用真实 LX 音源播放酷我《枫》。菜单准确列出 `SQ`、`HQ`、`192k`、`128k`，SQ 被默认选中；选择 `HQ` 后实际播放保持 `PLAYING`，媒体会话速度仍为 1.5、应用内音量仍为 52%。
- 播放详情从 `1411 kbps · 44 kHz · FLAC · SQ` 切换为 `320 kbps · 44 kHz · MP3 · HQ`，且进度从切换前附近位置恢复到 `1:04`。这证明选择影响真实 User API 取链和文件探测结果，而非只改标签。
- 验收截图：`/private/tmp/coral-quality-menu.png`、`/private/tmp/coral-quality-hq.png`。Android 实现和真机回归完成；iOS/鸿蒙真机待各平台运行时完成后补测，任务总状态保持 `DOING`。

## 2026-07-17 User API 实际返回音质（DOING）

- 桌面 `musicSdkRuntime.ts` 已确认 `musicUrl` 协议允许返回字符串，或 `{ data?: { url, type }, url, type }`；桌面保留返回的 `type`，只有字符串才使用请求质量兜底。
- 移动端原生桥只把 URL 字符串传回 Dart，因此脚本把 FLAC 请求降到 320k/128k 时，文件探测虽可显示 MP3，却仍以请求的 SQ 标识显示，信息不准确。
- 本轮将跨 Android bridge、Dart UserApiRunner、PlaybackResolver 与 PlayerState 传递已验证的实际 `type`；不从文件头猜测音乐源音质，也不改变请求音质、降级策略或缓存键。

## 2026-07-17 User API 实际返回音质（DONE for Android bridge/shared player）

- Android `UserApiRunner` 现把脚本返回的 URL 与可选 `type` 一同通过 MethodChannel 传给 Dart，兼容字符串、`{ url, type }` 与 `{ data: { url, type } }` 三种桌面协议形态。
- 新增 `ResolvedPlaybackUrl` 贯穿 User API、15 分钟 URL 缓存和 `PlayerController`；加载成功后播放器状态使用实际 `type`，没有 type 才保留用户请求质量。刷新缓存仍按请求质量作为键，故失败重试与既有 SQ→HQ 降级顺序不变。
- 验证：`preserves the actual quality returned by an enabled User API` 覆盖桥接 map `type: 320k` 到 `AudioQuality.high320k`；`shows the actual quality returned by the source` 覆盖播放器状态更新。`flutter test test/user_api_runner_test.dart test/playback_resolver_test.dart test/player_controller_test.dart -r compact` 21 项、`flutter analyze --no-fatal-infos`、`git diff --check` 均通过；`flutter build apk --debug` 成功产出 `build/app/outputs/flutter-apk/app-debug.apk`。真实脚本主动降档的 Android 点播回归留待下一次真机会话。
