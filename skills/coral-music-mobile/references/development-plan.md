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

| 项目 | 状态 | 证据/下一步 |
| --- | --- | --- |
| 移动仓库 | DOING | Batch 1、酷我排行榜及歌曲搜索纵向切片已完成；其余四源、歌单、音频和持久化待后续批次 |
| Flutter/Dart | READY-CANDIDATE | `3.27.5-ohos-0.1.1-Beta3` / Dart `3.6.2`；分析与测试通过，仍需评估 Beta 商店风险 |
| 鸿蒙工具链 | DOING | API 18、Ohpm 5.1.3、Node 22.16、Hvigor 5.18.6 可用；已生成 unsigned HAP，待 DevEco 调试签名 |
| Android 工具链 | READY | SDK 位于 `/opt/homebrew/share/android-commandlinetools`；API 35、Build Tools 33/35、NDK 26.1、Platform Tools 已安装，Debug APK 构建通过 |
| iOS 工具链 | DOING | Xcode 26.6、许可、首次启动和 CocoaPods 1.17.0 已完成；待安装 iOS 26.5 Platform Runtime |
| 真机 | BLOCKED | Flutter doctor 仅发现 macOS 与 Chrome，未发现三端真机 |
| 功能基线 | READY | 已核对桌面端九条 React 路由和十九个设置分组 |
| 商店政策审查 | TODO | 动态 User API、本地 HTTP 服务、后台下载需形成审查结论 |

## 当前业务批次

| 任务 | 状态 | 历史记录 |
| --- | --- | --- |
| B1-01 建立开发历史制度 | DONE | `development-history/2026-07-15-003-b1-01-development-history.md` |
| B1-02 拆分应用壳 | DONE | `development-history/2026-07-15-004-b1-02-app-structure.md` |
| B1-03 接入最小依赖 | DONE | `development-history/2026-07-15-005-b1-03-minimum-dependencies.md` |
| B1-04 建立领域模型 | DONE | `development-history/2026-07-15-006-b1-04-domain-models.md` |
| B1-05 建立 HTTP 客户端 | DONE | `development-history/2026-07-15-007-b1-05-http-client.md` |
| B1-06 建立具名路由 | DONE | `development-history/2026-07-15-008-b1-06-named-routing.md` |
| B2-01 提取酷我 fixture | DONE | `development-history/2026-07-15-009-b2-01-kuwo-fixtures.md` |
| B2-02 迁移酷我榜单 | DONE | `development-history/2026-07-15-010-b2-02-kuwo-leaderboard.md` |
| B2-03 排行榜状态 | DONE | `development-history/2026-07-15-011-b2-03-leaderboard-state.md` |
| B2-04 排行榜界面 | DONE | `development-history/2026-07-15-012-b2-04-leaderboard-ui.md` |
| B2-05 内存播放队列 | DONE | `development-history/2026-07-15-013-b2-05-playback-queue.md` |
| B2-06 迷你播放栏 | DONE | `development-history/2026-07-15-014-b2-06-mini-player.md` |
| B3-01 迁移酷我歌曲搜索 | DONE | `development-history/2026-07-15-015-b3-01-kuwo-track-search.md` |
| B3-02 搜索状态与界面 | DONE | `development-history/2026-07-15-016-b3-02-search-state-and-ui.md` |
| B3-03 酷狗排行榜可行性验证 | BLOCKED | `development-history/2026-07-15-017-b3-03-kugou-leaderboard-feasibility.md` |
| B3-04 迁移 QQ 音乐排行榜 | DONE | `development-history/2026-07-15-018-b3-04-qq-leaderboard.md` |
| B4-01 最小可播放闭环：音频引擎、取链与受限 User API | DOING | `development-history/2026-07-15-020-b4-01-minimum-playback-and-user-api.md` |
| B4-02 播放详情与歌词阅读界面 | DONE | `development-history/2026-07-15-021-b4-02-player-detail-and-lyrics-ui.md` |

## 里程碑

### Phase 0：可行性验证（2 周）

- `P0-01 [DONE]` 创建 `ios,android,ohos` 三端 Flutter 空壳；候选 SDK 已记录，包名锁定为 `com.coral.music.mobile`。
- `P0-02 [DOING]` Android SDK 已完成；Xcode/CocoaPods 已完成，仍需安装 iOS Platform Runtime 并完成鸿蒙签名。
- `P0-03 [BLOCKED]` 三端真机安装空壳并保存设备、系统版本和构建命令；鸿蒙需先配置调试签名。
- `P0-04 [DOING]` 最小播放器已实现并安装到 Android 真机；播放/暂停/seek 等待设备解锁后验收，再扩展锁屏、耳机和中断。
- `P0-05` HTTP Range 小样：远程 MP3/FLAC 播放和 seek，WebDAV Basic/Digest 凭据验证。
- `P0-06` SQLite migration 与安全存储小样；验证卸载/重装和系统备份边界。
- `P0-07` 文件选择、目录访问与分享导入小样。
- `P0-08` 后台下载小样：暂停、恢复、进程终止与系统重启后的状态协调。
- `P0-09 [DOING]` Android 受限 WebView User API 小样已实现并编译；仅 `musicUrl`、受控 HTTPS、超时和响应上限，等待真机取链验收。
- `P0-10` 完成依赖许可和三家商店政策结论。

退出门槛：`P0-03` 至 `P0-09` 在三端真机通过。若动态脚本不满足商店政策，锁定“商店版仅签名内置源”的既定降级，不阻断其它开发。

### Phase 1：工程与基础设施（2 周）

- `P1-01` 建立 CI：格式、分析、单测和 HAP/APK/iOS 无签名构建。
- `P1-02` 建立 Material 3 珊瑚主题、简中/繁中/英文和错误边界。
- `P1-03 [DOING]` 已建立 `go_router` 九入口、手机底栏、宽屏 Rail、迷你播放栏和独立播放详情页；播放器批次仍需补质量、队列与收藏。
- `P1-04 [DOING]` 已建立 Riverpod 排行榜/队列状态和 HTTP 脱敏诊断；完整启动状态待后续。
- `P1-05 [DOING]` 已落地 `Track`、来源、音质、榜单和分页类型；其余领域类型按真实调用方加入。
- `P1-06` 建立 SQLite v1、显式迁移、设置存储和安全凭据引用。
- `P1-07` 只为 Phase 0 已验证能力接入平台桥接。

退出门槛：九个入口可导航，排行榜为默认页；三端构建通过；数据库可创建、迁移和恢复失败备份。

### Phase 2：在线发现（4 周）

- `P2-01 [DOING]` 已提取酷我榜单 fixture；搜索、歌单和其余来源待迁移。
- `P2-02 [DOING]` 已建立五源枚举、酷我与 QQ 真实榜单；酷狗桌面端点 TLS 不可用而阻塞，其余两源待迁移。
- `P2-03 [DOING]` 已完成酷我歌曲搜索、分页、错误重试与旧响应隔离；歌单、综合、历史、热门词和其余来源待迁移。
- `P2-04` 实现歌单分类、排序、列表、详情、收藏和导入。
- `P2-05 [DOING]` 已实现酷我分页榜单及 QQ 当前榜单目录/详情，支持来源切换和跨导航状态；其余来源待迁移，跨来源缓存待后续。
- `P2-06 [DOING]` 已实现榜单/搜索旧响应隔离、图片惰性列表和错误重试；取消与持久缓存待后续。
- `P2-07 [DOING]` 已实现酷我/QQ 榜单播放全部及歌曲点击替换内存队列；歌单待迁移。

退出门槛：五个来源的 fixture 契约通过；默认榜单、搜索、歌单三条真机流程可用。

### Phase 3：播放器核心（5 周）

- `P3-01 [DOING]` B4-01 已实现最小 `AudioEngine`，三端构建通过；真机播放/seek 与 `MediaSessionBridge` 三端适配仍待完成。
- `P3-02 [DOING]` B4-01 已实现在线 `PlaybackResolver` 与 Android 受限 User API `musicUrl`；真机验收、四类来源、音质降级/换源/cache 后续扩展。
- `P3-03` 实现队列、三种模式、上一首/下一首、自动下一首、错误跳过和随机历史。
- `P3-04` 实现 seek、倍速、进度保存、重启恢复和音频焦点中断。
- `P3-05 [DOING]` B4-02 已实现可从迷你播放栏进入的播放详情、专辑卡片、进度和播放控制；共享队列、质量选择和收藏待补。
- `P3-06 [DOING]` B4-02 已实现歌词阅读入口与数据未就绪空态；歌词解析、逐字时间轴、翻译、罗马音、偏移、缓存和本地优先级待补。
- `P3-07` 实现后台元数据、媒体按键和平台允许的歌词展示。
- `P3-08` 实现评论入口、可关闭可视化及经 Phase 0 验证的平台音效。

退出门槛：四类来源均可播放/seek；锁屏和耳机控制通过；60 分钟连续播放无阻断错误。

### Phase 4：列表与媒体库（4 周）

- `P4-01` 列表 CRUD、排序和跨重启持久化。
- `P4-02` 歌曲批量选择、删除、复制、移动、置顶、排序和搜索。
- `P4-03` 列表导入导出、重复检测与复核。
- `P4-04` 本地文件/目录导入、元数据、封面、失败报告。
- `P4-05` 支持 P0 格式并按 Phase 0 结果扩展；完成 CUE 分轨。
- `P4-06` 实现历史、歌曲/歌单/专辑收藏和四种分类。
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

- `P6-01 [TODO]` B4-01 已提前受限 `musicUrl` 小样；文件/URL 导入、启用/删除、能力展示、完整隔离和商店版门控仍在本阶段。
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
