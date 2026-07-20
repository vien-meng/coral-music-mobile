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
| 商店政策审查   | TODO            | 动态 User API、后台下载需形成审查结论                                                                                                  |

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
| B3-19 搜索发现热词与歌手头像　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-130-b3-19-search-discovery-data.md`　　　　  |
| B3-07 迁移咪咕排行榜　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-033-b3-07-migu-leaderboard.md`　　　　　　　 |
| B3-08 网易云排行榜最小 HTTPS 切片　　　　　　　　　  | DOING　  | `development-history/2026-07-16-034-b3-08-netease-leaderboard.md`　　　　　  |
| B3-09 网易云歌曲搜索与来源选择　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-035-b3-09-netease-search.md`　　　　　　　　 |
| B3-10 酷我歌单 HTTPS 分类标签　　　　　　　　　　　  | DOING　  | `development-history/2026-07-16-036-b3-10-kuwo-song-list-tags.md`　　　　　  |
| B3-11 酷我歌单排序　　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-037-b3-11-kuwo-song-list-sort.md`　　　　　  |
| B3-12 酷我歌单搜索　　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-038-b3-12-kuwo-playlist-search.md`　　　　　 |
| B3-13 迁移咪咕歌曲搜索　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-16-039-b3-13-migu-search.md`　　　　　　　　　  |
| B3-15 迁移 QQ 音乐歌曲搜索　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-123-b3-15-qq-music-search.md` |
| B3-16 迁移酷狗音乐歌曲搜索　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-124-b3-16-kugou-music-search.md` |
| B3-17 迁移 QQ 音乐歌单广场与详情　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-125-b3-17-qq-playlist-plaza.md` |
| B3-18 迁移咪咕音乐歌单广场与详情　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-126-b3-18-migu-playlist-plaza.md` |
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
| B5-11 本地音频导入、目录扫描与播放闭环　　　　　　　 | DOING　  | `development-history/2026-07-20-090-b5-11-local-audio-import.md`　　　　 |
| B5-12 在线歌曲收藏入口　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-17-083-b5-12-online-track-favorite-actions.md` |
| B5-13 在线歌单收藏快照　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-087-b5-13-online-playlist-favorite-snapshots.md` |
| B5-19 本地专辑收藏快照　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-127-b5-19-local-album-favorites.md` |
| B6-01 在线歌曲下载队列　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-088-b6-01-online-download-queue.md` |
| B6-02 歌单下载全部　　　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-089-b6-02-playlist-download-all.md` |
| B6-18 默认播放音质设置　　　　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-122-b6-18-default-playback-quality-setting.md` |
| B6-20 下载文件音质展示与升级　　　　　　　　　　　　 | DOING　  | `development-history/2026-07-20-133-b6-20-download-quality-upgrade.md` |
| B4-01 最小可播放闭环：音频引擎、取链与受限 User API  | DOING　  | `development-history/2026-07-15-020-b4-01-minimum-playback-and-user-api.md`  |
| B4-02 播放详情与歌词阅读界面　　　　　　　　　　　　 | DONE　　 | `development-history/2026-07-15-021-b4-02-player-detail-and-lyrics-ui.md`　  |
| B4-03 队列前后切歌基础　　　　　　　　　　　　　　　 | DONE　  | `development-history/2026-07-15-022-b4-03-queue-navigation.md`　　　　　　　 |
| B4-04 播放完成自动下一首　　　　　　　　　　　　　　 | DONE　  | `development-history/2026-07-16-023-b4-04-auto-next.md`　　　　　　　　　　  |
| B4-05 播放模式与随机历史　　　　　　　　　　　　　　 | DONE　  | `development-history/2026-07-16-024-b4-05-playback-modes.md`　　　　　　　　 |
| B4-25 在线封面、曲目信息与歌词服务补全　　　　　　　 | DOING  | `development-history/2026-07-17-075-b4-25-online-artwork-and-lyrics.md`      |
| B4-26 播放音频文件信息探测　　　　　　　　　　　　　 | DOING  | `development-history/2026-07-17-076-b4-26-audio-file-info.md`                 |
| B4-27 iOS 受限 User API 运行时　　　　　　　　　　　 | DOING  | `development-history/2026-07-17-077-b4-27-ios-user-api-runtime.md`            |
| B4-28 启动恢复最近播放曲目　　　　　　　　　　　　　 | DOING  | `development-history/2026-07-17-078-b4-28-launch-playback-restore.md`         |
| B4-29 音频引擎重复错误去重　　　　　　　　　　　　　 | DOING  | `development-history/2026-07-17-079-b4-29-engine-error-deduplication.md`     |
| B4-32 歌词兜底与重试反馈　　　　　　　　　　　　　　 | DOING  | `development-history/2026-07-20-131-b4-32-lyric-fallback-retry.md`          |
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
| B4-24 LX 音源运行时兼容与真机闭环　　　　　　　　　 | DONE　  | `development-history/2026-07-16-071-b4-24-lx-runtime-compatibility.md`　 |

### 2026-07-16 开发顺序修订

- `B5-01` 至 `B5-10` 已完成的 SQLite、列表和收藏基础保留，但暂停新增 Batch 5 范围；后续开发优先回到 Batch 4。
- 当前顺序为：B4-12 音源导入/启用/移除 → 在线取链与播放回归 → 进度恢复、后台媒体与歌词。只有播放器闭环达到可用标准后才恢复本地媒体库扩展。
- 本次修订记录：`development-history/2026-07-16-052-plan-b4-player-and-source-priority.md`。

### 2026-07-16 高保真 UI 重构修订

- 以用户提供的 Coral Music 设计稿作为移动端视觉基线，新增 UI-01 至 UI-06：设计系统/应用壳 → 首页/发现 → 搜索/详情 → 播放/歌词 → 我的/设置/音源管理 → 三端视觉回归。
- 本修订只改变表现层与导航信息架构；既有排行榜、搜索、音源、队列、播放器和数据库业务状态继续复用，不能用演示数据替代。
- `UI-01 [DOING]` 继续收口应用壳整体高保真；`UI-02 [DONE]` 已修复迷你播放栏被手机底部 Navbar 遮挡，记录：`development-history/2026-07-16-072-ui-02-mini-player-navbar-layout.md`；`UI-07 [DONE]` 已将 URL 音源导入前置并补齐真实脚本详情卡，记录：`development-history/2026-07-17-073-ui-07-source-import-details.md`；`UI-08 [DONE]` 已重排播放详情主控制区，记录：`development-history/2026-07-17-074-ui-08-player-control-layout.md`。完整计划：`development-history/2026-07-16-064-plan-high-fidelity-ui.md`。
- `UI-09 [DOING]` 按 TDesign 移动端规范重构共享主题与组件表现，不引入未验证的 `tdesign_flutter` 依赖；记录：`development-history/2026-07-17-085-ui-09-tdesign-foundation.md`。依赖放弃决策见 `development-history/2026-07-17-084-plan-tdesign-flutter-migration.md`。
- `UI-11 [DONE]` 修复排行榜横向卡在小高度下的双行标题溢出，记录：`development-history/2026-07-20-121-ui-11-leaderboard-card-overflow.md`。
- `UI-12 [DOING]` 已拆分播放详情的页面编排、主控、操作弹层、歌词和队列，并修复操作区对齐、下载首次恢复竞态、重复音量入口、定时文案和音质面板；Flutter 控件测试待 SDK 权限恢复后执行。记录：`development-history/2026-07-20-129-ui-12-player-actions.md`。
- `UI-13 [DOING]` 播放详情使用原生 `PageView` 左滑进入歌词、右滑返回播放；播放页仅在顶部下拉超过阈值时退出，歌词纵向滚动不触发关闭。记录：`development-history/2026-07-20-132-ui-13-player-swipe-navigation.md`。
- `UI-14 [DOING]` 歌词页改为顶部小封面与歌曲信息、中部独立滚动歌词、底部固定进度和播放主控；播放与歌词页复用同一传输控制组件。记录：`development-history/2026-07-20-134-ui-14-lyrics-composed-layout.md`。
- `UI-15 [DOING]` 修复壳外播放详情使用 `push` 进入壳内下载/音源页面造成的重复导航壳红屏，改为 `go` 切换目标位置。记录：`development-history/2026-07-20-135-ui-15-player-shell-navigation.md`。

## 里程碑

### Phase 0：可行性验证（2 周）

- `P0-01 [DONE]` 创建 `ios,android,ohos` 三端 Flutter 空壳；候选 SDK 已记录，包名锁定为 `com.coral.music.mobile`。
- `P0-02 [DOING]` Android SDK 已完成；Xcode/CocoaPods 已完成，仍需安装 iOS Platform Runtime 并完成鸿蒙签名。
- `P0-03 [DOING]` SM-N986U / Android 13 已安装 Debug 包并保存验收记录；iOS/鸿蒙仍需真机与鸿蒙调试签名。
- `P0-04 [DOING]` Android 真机已通过固定 HTTPS 音频播放、暂停状态、seek 与媒体焦点；iOS/鸿蒙播放、锁屏、耳机和中断待验收。
- `P0-05` HTTP Range 小样：远程 MP3/FLAC 播放和 seek，WebDAV Basic/Digest 凭据验证。
- `P0-06 [DOING]` B5-01 正在以 OpenHarmony 适配的 `flutter_sqflite` 固定版本验证 SQLite migration；卸载/重装、系统备份边界和安全存储仍待真机验证。
- `P0-07` 文件选择、目录访问与分享导入小样：选择本地文件、选择已授权目录递归扫描，至少导入一首本地音频并验证前台/后台播放、seek、同目录 LRC 与重启后的授权恢复。
- `P0-08` 后台下载小样：暂停、恢复、进程终止与系统重启后的状态协调。
- `P0-09 [DOING]` Android 受限 WebView User API 已真机通过 `kw` 的 `musicUrl` 取链与播放；iOS 已实现同 channel 的非持久 WKWebView/HTTPS-only 运行时并通过无签名编译，仍待 iPhone 导入真实 LX 脚本验收；鸿蒙运行时和商店门控待后续验证。
- `P0-10` 完成依赖许可和三家商店政策结论。

退出门槛：`P0-03` 至 `P0-09` 在三端真机通过。若动态脚本不满足商店政策，锁定“商店版仅签名内置源”的既定降级，不阻断其它开发。

### Phase 1：工程与基础设施（2 周）

- `P1-01` 建立 CI：格式、分析、单测和 HAP/APK/iOS 无签名构建。
- `P1-02` 建立 Material 3 珊瑚主题、简中/繁中/英文和错误边界。
- `P1-03 [DOING]` 已建立 `go_router` 九入口、手机底栏、宽屏 Rail、迷你播放栏和独立播放详情页；壳外播放器进入壳内功能统一使用位置切换，避免重复构建 `StatefulShellRoute`。播放器批次仍需补质量、队列与收藏。
- `P1-04 [DOING]` 已建立 Riverpod 排行榜/队列状态和 HTTP 脱敏诊断；完整启动状态待后续。
- `P1-05 [DOING]` 已落地 `Track`、来源、音质、榜单和分页类型；其余领域类型按真实调用方加入。
- `P1-06 [DOING]` B5-01 正在建立 SQLite v1、显式迁移和列表持久化；设置存储与安全凭据引用后续按真实调用方加入。
- `P1-07` 只为 Phase 0 已验证能力接入平台桥接。

退出门槛：九个入口可导航，排行榜为默认页；三端构建通过；数据库可创建、迁移和恢复失败备份。

### Phase 2：在线发现（4 周）

- `P2-01 [DOING]` 已提取酷我榜单 fixture；搜索、歌单和其余来源待迁移。
- `P2-02 [DOING]` 已建立五源枚举、酷我与 QQ 真实榜单，B3-07 已接入咪咕；B3-08 正在验证网易云最小 HTTPS 切片，酷狗桌面端点 TLS 不可用而阻塞。
- `P2-03 [DOING]` 已完成酷我/酷狗/QQ/网易云/咪咕歌曲搜索、分页、错误重试、旧响应隔离和酷我热搜词；B3-12 已补酷我歌单搜索，B3-13 已完成 SQLite 本机搜索历史、去重、清空和一键复搜，B3-14 至 B3-16 已将 QQ、酷狗纳入综合搜索并保持单源失败隔离。记录：`development-history/2026-07-20-117-b3-13-search-history.md`、`development-history/2026-07-20-118-b3-14-combined-search.md`、`development-history/2026-07-20-123-b3-15-qq-music-search.md`、`development-history/2026-07-20-124-b3-16-kugou-music-search.md`。
- `P2-04 [DOING]` B3-05/B3-10 已实现酷我热门歌单、HTTPS 分类标签、排序、搜索、详情和播放入口；B3-17/B3-18 已接入 QQ 与咪咕的热门/最新或推荐歌单、标签（咪咕）和详情。QQ/咪咕的旧 HTTP 或额外签名关键词搜索不进入移动端。B5-13 已实现本地收藏快照，B6-02 已实现歌单下载全部；网易云与酷狗待后续。记录：`development-history/2026-07-20-087-b5-13-online-playlist-favorite-snapshots.md`、`development-history/2026-07-20-125-b3-17-qq-playlist-plaza.md`、`development-history/2026-07-20-126-b3-18-migu-playlist-plaza.md`。
- `P2-05 [DOING]` 已实现酷我分页榜单及 QQ 当前榜单目录/详情，支持来源切换和跨导航状态；其余来源待迁移，跨来源缓存待后续。
- `P2-06 [DOING]` 已实现榜单/搜索旧响应隔离、图片惰性列表和错误重试；取消与持久缓存待后续。
- `P2-07 [DOING]` 已实现酷我/QQ 榜单播放全部及歌曲点击替换内存队列；歌单待迁移。

退出门槛：五个来源的 fixture 契约通过；默认榜单、搜索、歌单三条真机流程可用。

### Phase 3：播放器核心（5 周）

- `P3-01 [DOING]` B4-01 已实现最小 `AudioEngine`，Android 真机播放/seek 通过；底层 `just_audio.play()` 仅作为启动命令触发，控制器不会等待整首歌结束。B4-11 已在真实 LX 音源下完成排行榜播放全部、榜单点歌和搜索点播三条入口回归，稳定自动化入口覆盖待补。B4-22 将系统媒体处理器收敛在 `AudioEngine` 内，iOS/鸿蒙真机验收仍待完成。
- `P3-02 [DOING]` B4-01 已实现在线 `PlaybackResolver` 与 Android 受限 User API `musicUrl`，并通过真机 `kw` 取链；B4-12 已完成会话内音源管理，支持从原 HTTPS 地址刷新并在失败时恢复旧脚本；B4-13 已实现 URL 缓存/刷新，且脚本导入、启用、刷新或清除成功后会清空会话 URL 缓存，避免旧脚本地址复用；播放详情的用户主动重试也会强制重新取链。User API 返回的实际质量 type 会随缓存传入播放器，避免降档流仍显示 SQ；B4-19 已实现已声明质量内的降级重试。B4-26 已在真实 SQ/FLAC 流以 Range 总大小和 FLAC 总采样数显示平均 `1643 kbps · 44 kHz · FLAC · SQ`，未探测到的文件参数不再以理论规格伪回退。B4-27 已完成 iOS WKWebView/同步 MD5 的同协议编译校验，真机/真实脚本验证仍待平台 Runtime；本地、下载和 WebDAV 已直连各自地址且不走 User API；来源发现、鉴权 Range 和跨来源换源仍待后续扩展。
- `P3-03 [DOING]` B4-03 已实现队列首尾循环的上一首/下一首与详情页控制；详情页下一首已在 Android 真机切至《红尘客栈》并立即恢复 `PLAYING`。B4-04/B4-05 已在 Android 真机验证列表循环、单曲循环与随机自动切歌；B4-14/B4-15 已在真实 30 首队列验证非当前删除和拖动排序均不打断当前播放；B4-31 已将队列曲目、索引、模式和上下文安全恢复到 SQLite，但不自动播放。B4-06 失效音源自动跳过及其余平台回归待补。记录：`development-history/2026-07-20-114-b4-31-playback-queue-persistence.md`。
- `P3-04 [DOING]` seek 已在 B4-01 通过 Android 真机；B4-07 已接入 0.5–2.0 倍速控制，B4-16 已在真机验证 seek 至 `02:16` 后从播放历史恢复，恢复后的媒体位置为 `02:24`；B4-28 已在应用启动恢复最近曲目与合法进度但不自动播放，首次点击才重新取链；三端冷启动与音频焦点中断仍待后续集中验收。
- `P3-05 [DOING]` B4-02 已实现可从迷你播放栏进入的播放详情、专辑卡片、进度和播放控制；UI-14 已把歌词页收口为固定歌曲头、独立歌词视口和底部播放主控；B4-09 已提供共享队列抽屉、删除与拖动排序，B4-10 可切换当前曲目的已声明音质，播放详情顶部可真实收藏/取消收藏。平台音效仍待后续能力对接。
- `P3-06 [DOING]` B4-02 已实现歌词阅读入口，B4-17 已接通 User API 原文/翻译/罗马音与 LX 逐字 LRC、当前行高亮及 LRC `offset`；Android 真机逐字填充仅作用于当前行、完成行恢复普通色且无绿色进度条。当前启用音源变更会使同一曲目歌词自动重新获取，空态/失败态可手动重新加载；酷我原生回退受 HTTP/GB18030 协议约束，iOS/鸿蒙来源优先级与真机兼容待补。
- `P3-07 [DOING]` B4-22 已接入 `audio_service` 作为系统前台媒体运行时；SM-N986U / Android 13 已用真实 LX 音源验证播放进度、后台持续、系统播放/暂停及后台下一首队列切歌。连续应用内切歌后，后台 `PLAY_PAUSE` 与 `NEXT` 仍可工作，已关闭接收器被曲目切换禁用的风险。通知/锁屏卡、实体耳机、音频焦点中断及 iOS/鸿蒙验收仍待完成。
- `P3-08` 实现可关闭可视化及经 Phase 0 验证的平台音效。

退出门槛：四类来源均可播放/seek；锁屏和耳机控制通过；60 分钟连续播放无阻断错误。

### Phase 4：列表与媒体库（4 周）

- `P4-01 [DOING]` B5-01 正在建立三端 SQLite 与列表 schema；列表 CRUD、排序和跨重启真机验收后续完成。
- `P4-02` 歌曲批量选择、删除、复制、移动、置顶、排序和搜索。
- `P4-03 [DOING]` B5-17 已实现桌面端 `playListPart_v2` 单列表 JSON 的导入导出；导入新建列表并复用 SQLite 主键去重，WebDAV/User API 凭据不会写入文件。重复检测与批量清理待 B5-18。记录：`development-history/2026-07-20-106-b5-17-playlist-import-export.md`。
- `P4-04 [DOING]` B5-11 已接入系统文件选择与目录递归扫描、格式过滤、CUE、同目录 LRC 与 MP3/AAC ID3、FLAC、WAV、M4A、Ogg/Opus 的共享标签/封面读取，并写入现有列表、队列与 `AudioEngine`；目录授权恢复和三端真实格式验收待完成。记录：`development-history/2026-07-20-090-b5-11-local-audio-import.md`。
- `P4-05 [DOING]` 已完成 CUE 单文件分轨：解析 INDEX 01、持久化起止位置、从分轨起点播放、边界自动切歌并避免整轨重复导入；可解析 FLAC/MP3 文件总时长会补齐末曲时长和边界。mp3/flac/wav/m4a/aac/ogg/opus 的三端真机格式矩阵与后台回归待继续。记录：`development-history/2026-07-20-102-b5-15-cue-single-file-tracks.md`。
- `P4-06 [DOING]` B5-04/B5-12 已实现歌曲收藏及播放详情、搜索、排行榜和歌单详情入口；B5-13 已保存在线歌单本地收藏快照，B5-19 已保存专辑本地快照。B5-05/B5-14 已实现播放历史及按艺术家、专辑、类型、年份的本地曲目分类；类型/年份只使用 B5-11 已读取的真实标签，B5-16 已将完成下载歌曲纳入同一媒体库；三端媒体库回归待继续。记录：`development-history/2026-07-20-087-b5-13-online-playlist-favorite-snapshots.md`、`development-history/2026-07-20-095-b5-14-library-artist-album-categories.md`、`development-history/2026-07-20-103-b5-16-download-library-integration.md`、`development-history/2026-07-20-127-b5-19-local-album-favorites.md`。
- `P4-07` 实现不感兴趣规则并接入自动播放过滤。

退出门槛：1000 首列表操作稳定；本地文件从导入、歌词到后台播放全链路通过。

### Phase 5：下载与 WebDAV（4 周）

- `P5-01 [DOING]` B6-01 已实现单并发持久队列、前台自动开始、暂停/Range 续传、重试、取消和原子完成；B6-20 已允许完成任务选择严格更高的可用音质重新下载，旧文件不会被覆盖。后台调度、并发策略、系统导出与三端恢复验收待继续。记录：`development-history/2026-07-20-088-b6-01-online-download-queue.md`、`development-history/2026-07-20-133-b6-20-download-quality-upgrade.md`。
- `P5-02 [DOING]` 已实现默认“歌名 - 歌手”命名、`.part` 与成品冲突避让、原子完成及已完成文件的系统选择器导出；下载列表显示最终文件名、格式后缀和音质。自定义模板和三端真机验收待继续。记录：`development-history/2026-07-20-094-b6-06-download-file-naming.md`、`development-history/2026-07-20-116-b6-17-download-system-export.md`、`development-history/2026-07-20-133-b6-20-download-quality-upgrade.md`。
- `P5-03 [DOING]` B6-02 已固定歌单点击时的曲目快照、任务去重并逐首隔离失败加入 B6-01 队列；已显示入队/跳过统计，元数据写入和真机批量下载验收待继续。记录：`development-history/2026-07-20-089-b6-02-playlist-download-all.md`、`development-history/2026-07-20-101-b6-12-playlist-download-summary.md`。
- `P5-04 [DOING]` 已支持多个 WebDAV 连接的命名、保存、切换、删除与最近账户恢复；账户索引不含授权，Authorization 仍仅存系统安全存储。连接测试和错误归一化复用现有客户端；真实服务端与三端验收待继续。记录：`development-history/2026-07-20-098-b6-09-webdav-multi-account-management.md`。
- `P5-05 [DOING]` 已实现目录内搜索、根目录约束的返回上级、可点击面包屑、音频过滤与刷新；真实服务端回归待继续。记录：`development-history/2026-07-20-093-b6-05-webdav-browse-search.md`、`development-history/2026-07-20-099-b6-10-webdav-breadcrumb-navigation.md`。
- `P5-06 [DOING]` 已实现 WebDAV 带鉴权播放、下载和加入既有本地列表；真实服务器 Range seek、过期凭据和三端回归待继续。记录：`development-history/2026-07-20-100-b6-11-webdav-add-to-playlist.md`。

退出门槛：进程终止后下载状态恢复；WebDAV MP3/FLAC 可 seek；凭据泄漏扫描通过。

### Phase 6：高级能力与设置（4 周）

- `P6-01 [DOING]` B4-01 已提前受限 `musicUrl` 小样，B4-12 已实现脚本 URL、文件与粘贴导入、启用/删除与能力展示；B4-30 已将 HTTPS 来源地址/名称安全持久化并在启动时重新校验加载，本地会话脚本不保存。完整隔离和商店版门控仍在本阶段。记录：`development-history/2026-07-20-105-b4-30-user-api-url-persistence.md`。
- `P6-02 [DOING]` 已实现本地曲目级不感兴趣切换、关键词规则、查看、逐首恢复和清空，并在排行榜、歌单、本地列表和分类的“播放全部”建队前过滤；规则已经进入本机备份，关键词匹配采用安全直接包含，不影响手动点播。跨端导入与真机回归待继续。记录：`development-history/2026-07-20-104-b6-13-not-interested-track-rules.md`、`development-history/2026-07-20-109-b6-15-ignored-keyword-rules.md`。
- `P6-03 [DOING]` B6-14 已实现本机文件的资料备份、格式校验、恢复前统计预览和 SQLite 事务合并恢复；备份只包含列表/收藏/不感兴趣规则，不包含凭据、脚本、播放 URL 或下载文件。覆盖恢复、历史/下载任务迁移与三端文件选择验收待继续。记录：`development-history/2026-07-20-108-b6-14-library-backup-restore.md`。
- `P6-04 [DOING]` 已实现播放器会话内定时停止和当前曲结束停止；B6-16 已提供系统/浅色/深色主题持久化，模块描边由当前主题主色低饱和混合得出，且切换不重建路由；B6-18 已提供 SQ 默认的持久化播放质量并真实影响后续取链。网络代理、缓存、完整语言资源和诊断待继续。记录：`development-history/2026-07-20-096-b6-07-sleep-timer.md`、`development-history/2026-07-20-110-b6-16-theme-mode-preference.md`、`development-history/2026-07-20-113-ui-10-theme-tinted-module-borders.md`、`development-history/2026-07-20-122-b6-18-default-playback-quality-setting.md`。
- `P6-06 [DOING]` 已将设置与音源管理拆分，设置页只提供真实的音源、下载、WebDAV 与本地列表入口；主题、语言、代理等待实际持久化实现后加入。

退出门槛：设置与实际行为一致；User API 超时/崩溃不影响主进程；本地备份恢复可回滚。

### Phase 7：收口与发布（4–7 周）

- `P7-01 [DOING]` Android/iOS/OpenHarmony 已注册 `coralmusic://`；Android 真机已成功由系统启动 Activity，B7-02 已增加 Android `audio/*` 系统分享接收、私有文件复制和“分享导入”列表衔接；B7-03 将分享消费移动至应用根部，保证所有导航页面均可接收；B7-04 已归一化 `coralmusic:///player` 与 `coralmusic://player` 等链接的 Flutter 路由落点。真实文件分享、iOS/鸿蒙系统回调与 Android 完整落点仍待继续。记录：`development-history/2026-07-20-111-p7-01-deep-link-registration.md`、`development-history/2026-07-20-112-p7-02-android-shared-audio-import.md`、`development-history/2026-07-20-115-p7-03-global-shared-audio-import.md`、`development-history/2026-07-20-119-p7-04-deep-link-route-normalization.md`。
- `P7-02` 包名、版本、图标、启动页、签名、权限文案和隐私清单。
- `P7-03` 弱网、断网、网络切换、低内存、来电、耳机断开和进程终止测试。
- `P7-04` 性能、无障碍、国际化、敏感信息和依赖漏洞检查。
- `P7-05` TestFlight、AAB/APK、HAP 内测及三端同版回归。
- `P7-06` 商店素材、审核说明和动态脚本/后台音频能力说明。

## 任务依赖

- Phase 0 决定所有插件和平台实现，未通过的小样不得提前产品化。
- 在线发现依赖领域类型和 HTTP 基础，不依赖完整播放器。
- 播放器依赖在线 fixture 与平台音频小样；列表只依赖稳定 `Track`。
- 下载与 WebDAV 复用播放器解析和平台后台任务，不建立第二套状态机。
- 本地备份与 User API 在核心数据稳定后进入，避免反复迁移协议。

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
- 商店审核资料明确说明后台音频、文件权限和 User API 行为。
