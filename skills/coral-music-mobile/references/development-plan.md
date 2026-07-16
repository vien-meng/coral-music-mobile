# 珊瑚音乐移动端执行计划

## 目录

- [交付原则](#交付原则)
- [当前状态](#当前状态)
- [里程碑](#里程碑)
- [任务依赖](#任务依赖)
- [人员与节奏](#人员与节奏)
- [持续验证](#持续验证)
- [发布门槛](#发布门槛)

## 交付原则

- 三端同步验收，功能以 `feature-parity.md` 为完成口径。
- 每次只领取能形成纵向可运行结果的任务；不批量创建空 service、repository 或页面。
- Phase 0 的后台播放、Range、安全存储和 User API 沙箱是 Go/No-Go 门槛。
- 工期按 2 名 Flutter、iOS/Android/鸿蒙原生支持各 1 名、QA 1 名估算为 28–32 周；Phase 0 后调整。

## 当前状态

记录日期：2026-07-15。

| 项目           | 状态            | 证据/下一步                                                                                                                             |
| -------------- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 移动仓库       | DOING           | Batch 1、酷我排行榜及歌曲搜索纵向切片已完成；其余四源、歌单、音频和持久化待后续批次                                                     |
| Flutter/Dart   | READY-CANDIDATE | `3.27.5-ohos-0.1.1-Beta3` / Dart `3.6.2`；分析与测试通过，仍需评估 Beta 商店风险                                                        |
| 鸿蒙工具链     | DOING           | API 18、Ohpm 5.1.3、Node 22.16、Hvigor 5.18.6 可用；已生成 unsigned HAP，待 DevEco 调试签名                                             |
| Android 工具链 | READY           | SDK 位于 `/opt/homebrew/share/android-commandlinetools`；API 35、Build Tools 33/35、NDK 26.1、Platform Tools 已安装，Debug APK 构建通过 |
| iOS 工具链     | DOING           | Xcode 26.6、许可、首次启动和 CocoaPods 1.17.0 已完成；待安装 iOS 26.5 Platform Runtime                                                  |
| 真机           | DOING           | SM-N986U / Android 13 已完成最小播放、seek 与 User API 取链验收；iOS、鸿蒙真机仍待配置                                                  |
| 功能基线       | READY           | 已核对桌面端九条 React 路由和十九个设置分组                                                                                             |
| 商店政策审查   | TODO            | 动态 User API、本地 HTTP 服务、后台下载需形成审查结论                                                                                   |

## 当前业务批次

| 任务　　　　　　　　　　　　　　　　　　　　　　　　 | 状态　　 | 历史记录　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| ---------------------------------------------------- | -------- | ---------------------------------------------------------------------------- |
| B1-01 建立开发历史制度　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-003-b1-01-development-history.md`　　　　　  |
| B1-02 拆分应用壳　　　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-004-b1-02-app-structure.md`　　　　　　　　  |
| B1-03 接入最小依赖　　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-005-b1-03-minimum-dependencies.md`　　　　　 |
| B1-04 建立领域模型　　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-006-b1-04-domain-models.md`　　　　　　　　  |
| B1-05 建立 HTTP 客户端　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-007-b1-05-http-client.md`　　　　　　　　　  |
| B1-06 建立具名路由　　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-008-b1-06-named-routing.md`　　　　　　　　  |
| B2-01 提取酷我 fixture　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-009-b2-01-kuwo-fixtures.md`　　　　　　　　  |
| B2-02 迁移酷我榜单　　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-010-b2-02-kuwo-leaderboard.md`　　　　　　　 |
| B2-03 排行榜状态　　　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-011-b2-03-leaderboard-state.md`　　　　　　  |
| B2-04 排行榜界面　　　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-012-b2-04-leaderboard-ui.md`　　　　　　　　 |
| B2-05 内存播放队列　　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-013-b2-05-playback-queue.md`　　　　　　　　 |
| B2-06 迷你播放栏　　　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-014-b2-06-mini-player.md`　　　　　　　　　  |
| B3-01 迁移酷我歌曲搜索　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-015-b3-01-kuwo-track-search.md`　　　　　　  |
| B3-02 搜索状态与界面　　　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-016-b3-02-search-state-and-ui.md`　　　　　  |
| B3-03 酷狗排行榜可行性验证　　　　　　　　　　　　　 | BLOCKED  | `development-history/2026-07-15-017-b3-03-kugou-leaderboard-feasibility.md`  |
| B3-04 迁移 QQ 音乐排行榜　　　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-018-b3-04-qq-leaderboard.md`　　　　　　　　 |
| B3-05 酷我歌单广场纵向切片　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-031-b3-05-kuwo-song-list.md`　　　　　　　　 |
| B3-06 酷我热搜词　　　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-032-b3-06-kuwo-hot-search.md`　　　　　　　  |
| B3-07 迁移咪咕排行榜　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-033-b3-07-migu-leaderboard.md`　　　　　　　 |
| B3-08 网易云排行榜最小 HTTPS 切片　　　　　　　　　  | DOING　  | `development-history/2026-07-16-034-b3-08-netease-leaderboard.md`　　　　　  |
| B3-09 网易云歌曲搜索与来源选择　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-035-b3-09-netease-search.md`　　　　　　　　 |
| B3-10 酷我歌单 HTTPS 分类标签　　　　　　　　　　　  | DOING　  | `development-history/2026-07-16-036-b3-10-kuwo-song-list-tags.md`　　　　　  |
| B3-11 酷我歌单排序　　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-037-b3-11-kuwo-song-list-sort.md`　　　　　  |
| B3-12 酷我歌单搜索　　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-038-b3-12-kuwo-playlist-search.md`　　　　　 |
| B3-13 迁移咪咕歌曲搜索　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-039-b3-13-migu-search.md`　　　　　　　　　  |
| B4-14 队列追加与安全删除　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-040-b4-14-queue-editing.md`　　　　　　　　  |
| B4-15 队列拖动排序　　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-041-b4-15-queue-reorder.md`　　　　　　　　  |
| B5-01 三端 SQLite 可行性与列表 Schema v1　　　　　　 | DOING　  | `development-history/2026-07-16-042-b5-01-sqlite-list-schema.md`　　　　　　 |
| B5-02 我的列表 CRUD 与排序　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-043-b5-02-library-crud.md`　　　　　　　　　 |
| B5-03 列表歌曲成员与去重　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-044-b5-03-playlist-tracks.md`　　　　　　　  |
| B5-04 收藏歌曲与播放页入口　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-045-b5-04-favorite-tracks.md`　　　　　　　  |
| B5-05 播放历史与音乐分类入口　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-046-b5-05-play-history.md`　　　　　　　　　 |
| B5-06 列表内搜索与来源筛选　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-047-b5-06-playlist-search-filter.md`　　　　 |
| B5-07 列表歌曲批量选择与删除　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-048-b5-07-playlist-batch-delete.md`　　　　  |
| B5-08 列表歌曲拖动排序　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-049-b5-08-playlist-track-reorder.md`　　　　 |
| B5-09 列表歌曲复制与移动　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-050-b5-09-playlist-copy-move.md`　　　　　　 |
| B5-10 列表歌曲批量置顶　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-051-b5-10-playlist-pin-top.md`　　　　　　　 |
| B4-01 最小可播放闭环：音频引擎、取链与受限 User API  | DOING　  | `development-history/2026-07-15-020-b4-01-minimum-playback-and-user-api.md`  |
| B4-02 播放详情与歌词阅读界面　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-021-b4-02-player-detail-and-lyrics-ui.md`　  |
| B4-03 队列前后切歌基础　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-15-022-b4-03-queue-navigation.md`　　　　　　　 |
| B4-04 播放完成自动下一首　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-023-b4-04-auto-next.md`　　　　　　　　　　  |
| B4-05 播放模式与随机历史　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-024-b4-05-playback-modes.md`　　　　　　　　 |
| B4-06 失效音源自动跳过　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-025-b4-06-error-skip.md`　　　　　　　　　　 |
| B4-07 播放倍速控制　　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-026-b4-07-playback-rate.md`　　　　　　　　  |
| B4-08 播放音量控制　　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-027-b4-08-volume-control.md`　　　　　　　　 |
| B4-09 共享播放队列面板　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-028-b4-09-queue-panel.md`　　　　　　　　　  |
| B4-10 当前曲目音质选择　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-029-b4-10-quality-selection.md`　　　　　　  |
| B4-11 在线列表播放入口接线　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-030-b4-11-online-play-entry.md`　　　　　　  |
| B4-12 User API 音源导入与运行时管理　　　　　　　　　 | DOING　  | `development-history/2026-07-16-053-b4-12-user-api-source-management.md`　　 |
| B4-13 在线取链缓存与过期刷新重试　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-054-b4-13-playback-url-cache.md`　　　　　  |
| B4-16 播放进度保存与历史继续播放　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-055-b4-16-playback-progress-resume.md`　　  |
| B4-17 User API 歌词与播放详情时间轴　　　　　　　　　 | DOING　  | `development-history/2026-07-16-056-b4-17-user-api-lyrics.md`　　　　　　  |
| B4-18 Android MediaSession 前台媒体控制　　　　　　　 | DOING　  | `development-history/2026-07-16-057-b4-18-android-media-session.md`　　　  |
| B4-19 在线音质降级重试　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-058-b4-19-quality-fallback.md`　　　　　  |
| B4-20 User API HTTPS 地址导入　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-059-b4-20-user-api-url-import.md`　　　　 |
| B4-21 同目录本地 LRC 优先读取　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-060-b4-21-local-lrc-priority.md`　　　　 |
| B4-22 三端后台播放运行时与系统媒体服务　　　　　　　 | DOING　  | `development-history/2026-07-16-061-b4-22-background-audio-service.md`　 |
| B4-23 快速切歌旧请求隔离　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-063-b4-23-play-request-isolation.md`　 |

### 2026-07-16 开发顺序修订

- `B5-01` 至 `B5-10` 已完成的 SQLite、列表和收藏基础保留，但暂停新增 Batch 5 范围；后续开发优先回到 Batch 4。
- 当前顺序为：B4-12 音源导入/启用/移除 → 在线取链与播放回归 → 进度恢复、后台媒体与歌词。只有播放器闭环达到可用标准后才恢复本地媒体库扩展。
- 本次修订记录：`development-history/2026-07-16-052-plan-b4-player-and-source-priority.md`。

### 2026-07-16 高保真 UI 重构修订

- 以用户提供的 Coral Music 设计稿作为移动端视觉基线，新增 UI-01 至 UI-06：设计系统/应用壳 → 首页/发现 → 搜索/详情 → 播放/歌词 → 我的/设置/音源管理 → 三端视觉回归。
- 本修订只改变表现层与导航信息架构；既有排行榜、搜索、音源、队列、播放器和数据库业务状态继续复用，不能用演示数据替代。
- 当前任务为 `UI-01 [DOING]`，记录：`development-history/2026-07-16-065-ui-01-design-system-and-shell.md`；完整计划：`development-history/2026-07-16-064-plan-high-fidelity-ui.md`。

## 里程碑

### Phase 0：可行性验证（2 周）

- `P0-01 [DONE]` 创建 `ios,android,ohos` 三端 Flutter 空壳；候选 SDK 已记录，包名锁定为 `com.coral.music.mobile`。
- `P0-02 [DOING]` Android SDK 已完成；Xcode/CocoaPods 已完成，仍需安装 iOS Platform Runtime 并完成鸿蒙签名。
- `P0-03 [DOING]` SM-N986U / Android 13 已安装 Debug 包并保存验收记录；iOS/鸿蒙仍需真机与鸿蒙调试签名。
- `P0-04 [DOING]` Android 真机已通过固定 HTTPS 音频播放、暂停状态、seek 与媒体焦点；iOS/鸿蒙播放、锁屏、耳机和中断待验收。
- `P0-05` HTTP Range 小样：远程 MP3/FLAC 播放和 seek，WebDAV Basic/Digest 凭据验证。
- `P0-06 [DOING]` B5-01 正在以 OpenHarmony 适配的 `flutter_sqflite` 固定版本验证 SQLite migration；卸载/重装、系统备份边界和安全存储仍待真机验证。
- `P0-07` 文件选择、目录访问与分享导入小样。
- `P0-08` 后台下载小样：暂停、恢复、进程终止与系统重启后的状态协调。
- `P0-09 [DOING]` Android 受限 WebView User API 已真机通过 `kw` 的 `musicUrl` 取链与播放；iOS/鸿蒙运行时和商店门控待后续验证。
- `P0-10` 完成依赖许可和三家商店政策结论。

退出门槛：`P0-03` 至 `P0-09` 在三端真机通过。若动态脚本不满足商店政策，锁定“商店版仅签名内置源”的既定降级，不阻断其它开发。

### Phase 1：工程与基础设施（2 周）

- `P1-01` 建立 CI：格式、分析、单测和 HAP/APK/iOS 无签名构建。
- `P1-02` 建立 Material 3 珊瑚主题、简中/繁中/英文和错误边界。
- `P1-03 [DOING]` 已建立 `go_router` 九入口、手机底栏、宽屏 Rail、迷你播放栏和独立播放详情页；播放器批次仍需补质量、队列与收藏。
- `P1-04 [DOING]` 已建立 Riverpod 排行榜/队列状态和 HTTP 脱敏诊断；完整启动状态待后续。
- `P1-05 [DOING]` 已落地 `Track`、来源、音质、榜单和分页类型；其余领域类型按真实调用方加入。
- `P1-06 [DOING]` B5-01 正在建立 SQLite v1、显式迁移和列表持久化；设置存储与安全凭据引用后续按真实调用方加入。
- `P1-07` 只为 Phase 0 已验证能力接入平台桥接。

退出门槛：九个入口可导航，排行榜为默认页；三端构建通过；数据库可创建、迁移和恢复失败备份。

### Phase 2：在线发现（4 周）

- `P2-01 [DOING]` 已提取酷我榜单 fixture；搜索、歌单和其余来源待迁移。
- `P2-02 [DOING]` 已建立五源枚举、酷我与 QQ 真实榜单，B3-07 已接入咪咕；B3-08 正在验证网易云最小 HTTPS 切片，酷狗桌面端点 TLS 不可用而阻塞。
- `P2-03 [DOING]` 已完成酷我/网易云歌曲搜索、分页、错误重试、旧响应隔离和酷我热搜词；B3-12 正在补酷我歌单搜索，综合/历史和其余来源待迁移。
- `P2-04 [DOING]` B3-05 已实现酷我热门歌单列表、详情和播放入口；B3-10 正在补可用 HTTPS 分类标签，排序、收藏、导入及其他来源待后续。
- `P2-05 [DOING]` 已实现酷我分页榜单及 QQ 当前榜单目录/详情，支持来源切换和跨导航状态；其余来源待迁移，跨来源缓存待后续。
- `P2-06 [DOING]` 已实现榜单/搜索旧响应隔离、图片惰性列表和错误重试；取消与持久缓存待后续。
- `P2-07 [DOING]` 已实现酷我/QQ 榜单播放全部及歌曲点击替换内存队列；歌单待迁移。

退出门槛：五个来源的 fixture 契约通过；默认榜单、搜索、歌单三条真机流程可用。

### Phase 3：播放器核心（5 周）

- `P3-01 [DOING]` B4-01 已实现最小 `AudioEngine`，Android 真机播放/seek 通过；B4-11 正在把排行榜的点歌/播放全部接入统一播放控制器。B4-22 将系统媒体处理器收敛在 `AudioEngine` 内，iOS/鸿蒙真机验收仍待完成。
- `P3-02 [DOING]` B4-01 已实现在线 `PlaybackResolver` 与 Android 受限 User API `musicUrl`，并通过真机 `kw` 取链；B4-12 已完成会话内音源管理，B4-13 已实现 URL 缓存/刷新，B4-19 已实现已声明质量内的降级重试。本地、下载和 WebDAV 已直连各自地址且不走 User API；来源发现、鉴权 Range 和跨来源换源仍待后续扩展。
- `P3-03 [DOING]` B4-03 已实现队列首尾循环的上一首/下一首与详情页控制；B4-04 已接入完成事件自动切歌，B4-05 正在扩展三种模式与随机历史，B4-06 正在补失效音源自动跳过。切歌后即时恢复播放仍待 Android 回归。
- `P3-04 [DOING]` seek 已在 B4-01 通过 Android 真机；B4-07 已接入 0.5–2.0 倍速控制，B4-16 已实现进度保存和从历史继续播放；应用启动恢复和音频焦点中断待后续。
- `P3-05 [DOING]` B4-02 已实现可从迷你播放栏进入的播放详情、专辑卡片、进度和播放控制；B4-09 正在实现共享队列面板，质量选择和收藏待补。
- `P3-06 [DOING]` B4-02 已实现歌词阅读入口，B4-17 已接通 User API 原文/翻译/罗马音与 LX 逐字 LRC、当前行高亮及 LRC `offset`；缓存和本地优先级待补。
- `P3-07 [DOING]` B4-22 已接入 `audio_service` 作为系统前台媒体运行时，Android Debug 构建通过；播放/暂停/seek 与上一首/下一首已进入统一处理器。SM-N986U 冷启动已验证不再产生空闲 `media-session`；首次播放、锁屏、耳机、音频焦点中断及三端验收仍待完成。
- `P3-08` 实现评论入口、可关闭可视化及经 Phase 0 验证的平台音效。

退出门槛：四类来源均可播放/seek；锁屏和耳机控制通过；60 分钟连续播放无阻断错误。

### Phase 4：列表与媒体库（4 周）

- `P4-01 [DOING]` B5-01 正在建立三端 SQLite 与列表 schema；列表 CRUD、排序和跨重启真机验收后续完成。
- `P4-02` 歌曲批量选择、删除、复制、移动、置顶、排序和搜索。
- `P4-03` 列表导入导出、重复检测与复核。
- `P4-04` 本地文件/目录导入、元数据、封面、失败报告。
- `P4-05` 支持 P0 格式并按 Phase 0 结果扩展；完成 CUE 分轨。
- `P4-06 [DOING]` B5-04 已实现歌曲收藏与播放详情入口；B5-05 已实现播放历史写入和读取，歌单/专辑收藏及专辑/艺术家/类型/年份分类待继续。
- `P4-07` 实现不感兴趣规则并接入自动播放过滤。

退出门槛：1000 首列表操作稳定；本地文件从导入、歌词到后台播放全链路通过。

### Phase 5：下载与 WebDAV（4 周）

- `P5-01` 持久下载队列、并发调度、自动开始、暂停/恢复/重试/取消。
- `P5-02` 文件命名兼容、临时文件校验、原子完成和系统导出。
- `P5-03` 经验证的平台支持下写入歌词、封面或标签。
- `P5-04` WebDAV 账号、凭据引用、连接测试和错误归一化。
- `P5-05` 目录、面包屑、搜索、音频过滤和刷新。
- `P5-06` WebDAV Range 播放、加入列表和下载。

退出门槛：进程终止后下载状态恢复；WebDAV MP3/FLAC 可 seek；凭据泄漏扫描通过。

### Phase 6：高级能力与设置（4 周）

- `P6-01 [DOING]` B4-01 已提前受限 `musicUrl` 小样，B4-12 提前实现会话内脚本导入、启用/删除与能力展示；安全持久化、文件/URL 系统导入、完整隔离和商店版门控仍在本阶段。
- `P6-02` 兼容桌面列表与不感兴趣同步协议；前台服务端状态可见。
- `P6-03` 备份、完整性校验、版本迁移和恢复预览。
- `P6-04` 网络代理、缓存、定时停止、主题、语言和诊断。
- `P6-05` 前台 OpenAPI、局域网警告、授权和关闭清理。
- `P6-06` 完成所有移动端有效设置；删除无行为开关。

退出门槛：设置与实际行为一致；User API 超时/崩溃不影响主进程；备份恢复可回滚。

### Phase 7：收口与发布（4–7 周）

- `P7-01` 深链 `coralmusic://`、文件分享入口和系统返回行为。
- `P7-02` 包名、版本、图标、启动页、签名、权限文案和隐私清单。
- `P7-03` 弱网、断网、网络切换、低内存、来电、耳机断开和进程终止测试。
- `P7-04` 性能、无障碍、国际化、敏感信息和依赖漏洞检查。
- `P7-05` TestFlight、AAB/APK、HAP 内测及三端同版回归。
- `P7-06` 商店素材、审核说明、动态脚本/后台音频/局域网能力说明。

## 任务依赖

- Phase 0 决定所有插件和平台实现，未通过的小样不得提前产品化。
- 在线发现依赖领域类型和 HTTP 基础，不依赖完整播放器。
- 播放器依赖在线 fixture 与平台音频小样；列表只依赖稳定 `Track`。
- 下载与 WebDAV 复用播放器解析和平台后台任务，不建立第二套状态机。
- 同步、备份、User API 和 OpenAPI 在核心数据稳定后进入，避免反复迁移协议。

## 人员与节奏

- Flutter A：应用壳、在线发现、列表与设置。
- Flutter B：播放器、歌词、下载、WebDAV。
- 平台工程：iOS、Android、鸿蒙各负责媒体、后台、权限和发布；Phase 0 可并行。
- QA：从 Phase 0 建立三端设备矩阵和每阶段回归，不等到 Phase 7 才介入。
- 每周只以可运行纵向切片验收，不以新增文件数或页面占位统计进度。

## 持续验证

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build hap --debug
flutter build apk --debug
flutter build ios --debug --no-codesign
```

- PR 必须运行纯 Dart 单测；平台任务必须附对应真机记录。
- 契约测试固定桌面端 fixture，不在测试中访问不稳定在线服务。
- 发布前再运行真实来源冒烟，失败需区分接口变化与客户端回归。

## 发布门槛

- `feature-parity.md` 所有 P0/P1 为 `DONE` 或有批准的平台等价记录。
- HAP、AAB/IPA 使用同一业务版本和数据 schema。
- 三端后台播放、媒体按键、Range seek、下载恢复和安全存储通过真机验收。
- 日志、SQLite、备份和崩溃报告中无明文凭据。
- 商店审核资料明确说明后台音频、局域网服务、文件权限和 User API 行为。
