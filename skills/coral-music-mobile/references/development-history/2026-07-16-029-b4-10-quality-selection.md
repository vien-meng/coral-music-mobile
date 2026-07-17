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
