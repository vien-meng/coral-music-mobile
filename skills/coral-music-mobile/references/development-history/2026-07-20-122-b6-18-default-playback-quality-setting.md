# B6-18 默认播放音质设置

- 阶段：Batch 6 / Phase 6
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标与范围

让用户在设置页选择默认在线播放音质，并安全持久化；后续未显式选择质量的点播按该偏好请求，歌曲详情手动切换保持优先。

不做：伪造系统音频能力、强制超出音源声明的品质，或在切换设置时打断当前播放。

## 实施与依赖

- 复用现有 `FlutterSecureStorage` 的主题偏好模式，不新增设置数据库或依赖。
- 复用 `AudioQuality` 顺序：优先选择不高于偏好的最近可用档；若音源只提供更高档则使用其最高可用档，若无声明仍按 SQ 请求。
- 应用根部监听偏好变化，将其传给既有 `PlayerController`；播放页手动质量选择继续直接调用既有接口。

## 桌面端对照

对照 `coral-music-desktop` 的播放质量设置与当前移动端 `defaultPlaybackQuality`。移动端不复制桌面音效/独占输出设置，只控制 User API 取链质量。

## 实际修改与验证

- 新增安全持久化的 `DefaultQualityController`，默认 SQ（FLAC）；应用根部只监听偏好变化，不因设置切换重建播放器或中断当前歌曲。
- `PlayerController` 使用偏好选择下一次自动取链质量；手动质量切换仍优先，音源不提供目标档时选择最近可用档。
- 设置页加入“默认播放音质”，完整展示母带、全景声、Hi-Res、SQ、HQ、192k、128k 的实际质量语义。
- `flutter analyze`、`flutter test test/player_controller_test.dart`（19 项，含默认 HQ 请求断言）和 `git diff --check` 通过；Debug APK 已成功安装至 Samsung Android 13 真机 `R5CR70B7SMA`，待在设置中选择并点播进行人工确认。
