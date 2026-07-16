# Changelog

All notable changes to 珊瑚音乐移动端 (Coral Music Mobile) will be documented in this file.

## [0.1.0] - 2026-07-16(03)

### 酷我歌单搜索

- 接入 HTTPS 歌单搜索（`search.kuwo.cn/r.s`，`ft=playlist`），支持结果解析、分页与广场搜索输入
- 提交空关键词恢复当前标签与排序的广场请求

### 咪咕歌曲搜索

- 迁移咪咕签名 HTTPS 搜索（固定 deviceId、时间戳、MD5 签名，jadeite 接口）
- 解析咪咕嵌套搜索结果并开放咪咕搜索来源

### 播放队列编辑

- 实现按 Track ID 去重的队列追加、非当前项删除与当前索引修正
- 随机历史索引同步修正；当前播放项禁用删除
- 实现未播放项拖动排序（`ReorderableListView`），当前索引重算，随机历史重置
- 当前项无拖动手柄

### SQLite 持久化基础

- 引入 OpenHarmony-SIG 适配的 `flutter_sqflite`（固定提交 `0bd638a`），三端共用 SQLite
- 建立 `user_playlist` schema v1：id、名称、位置、创建/更新时间；不保存凭据
- HAP / APK Debug 构建通过，注册器包含 `SqflitePlugin`

### 我的列表

- 新增 `LibraryStore`、`LibraryController` 与 `/list` 页面，UI 不直接访问 SQLite
- 实现列表创建、重命名、删除与拖动排序；排序写回数据库后重新读取
- schema 升级至 v2，新增 `user_playlist_track`（`(playlist_id, track_id)` 去重）
- 列表详情支持列表内播放、单曲移除
- 排行榜、搜索、歌单详情三个在线入口增加"添加到我的列表"选择器

### 收藏歌曲

- 使用固定内部 id `favorites` 复用 `user_playlist_track`，不复制曲目存储
- `/favorites` 路由接为实际页面，可读取、播放、移除收藏歌曲
- 播放详情增加收藏状态读取与收藏/取消收藏按钮

### 播放历史

- schema 升级至 v3，新增 `play_history`（`Track.id` 主键，最多 1000 条）
- `PlayerController` 仅在 `playing` 首次到达时异步记录，写入失败不影响播放
- `/library` 替换为播放历史页面，可读取、清空、点击恢复队列并播放

### 列表内搜索与来源筛选

- 列表详情按标题、歌手、专辑、来源标识检索
- 按 online / local / download / webdav 四类来源筛选
- 内存过滤，不新增数据库索引与网络请求

## [0.1.0] - 2026-07-16(02)

### 咪咕排行榜

- 新增 `MiguCatalogService`，迁移咪咕固定榜单目录与 HTTPS 详情请求
- 映射 PQ/HQ/SQ/ZQ 音质并归一化为共享 `Track`
- 接入现有多来源分派器与排行榜来源选择器

### 网易云排行榜

- 新增 `NeteaseCatalogService`，通过公开 HTTPS 歌单详情端点读取固定主榜
- 接入现有多来源分派器与来源选择器

### 网易云歌曲搜索

- `NeteaseCatalogService` 增加公开 HTTPS 歌曲搜索及结果归一化
- 搜索页支持酷我/网易云来源切换，复用请求序号隔离旧响应
- 酷我空态保留热词，网易云空态不展示无效热词

### 酷我歌单分类标签

- `KuwoPlaylistService` 新增可用标签解析与按 tagId 加载
- 歌单广场增加横向分类筛选控件；`digest=43` 等仅 HTTP 路径不展示

### 酷我歌单排序

- 歌单广场增加 `hot` / `new` 排序参数与下拉选择
- 切换排序或标签均从第一页重新加载

## [0.1.0] - 2026-07-16(01)

### QQ 音乐排行榜

- 对接 QQ 音乐固定榜单与歌曲详情（HTTPS POST，期数自动取当前）
- 实现 `MultiSourceOnlineCatalogService` 多来源分派器，支持酷我/QQ 来源切换
- 音乐源下拉支持 QQ 来源
- 使用 requestId 机制防止跨来源响应覆盖

### 酷我歌单广场

- 实现酷我热门歌单广场列表与详情页
- 歌单详情支持歌曲列表、播放全部与单曲点击播放
- 新增 `OnlinePlaylist` 与 `PlaylistDetail` 歌单领域模型

### 酷我热搜词

- 对接酷我热搜词 API（HTTPS），搜索空态显示热词 Chip，点击回填并搜索

### 音频引擎与播放器

- 引入 `just_audio` / `just_audio_harmonyos` 三端音频引擎，实现 `AudioEngine` 抽象及 `JustAudioEngine` 实现
- 实现最小可播放闭环：`AudioEngine` + `PlaybackResolver` + 受限 User API
- Android WebView User API 桥：最小 `lx` 对象，强制 HTTPS、GET/POST、20s 超时
- 播放队列上一首/下一首（首尾循环）、播放完成自动下一首
- 三种播放模式：列表循环、单曲循环、随机（含本轮已播放索引）
- 新增 `PlaybackMode` 枚举（listLoop / singleLoop / shuffle）
- 失效音源自动跳过，全队列失败后停止
- 0.5–2.0 倍速控制、0–100% 应用内音量控制
- 当前曲目音质选择，切换后重新取链加载
- 排行榜、搜索、歌单详情播放入口统一接入 `PlayerController`

### 播放详情页

- 独立 `/player` 路由，珊瑚色渐变沉浸式详情：圆形封面、进度条、歌词入口
- 迷你播放栏接入真实播放/暂停状态、进度条和可 seek 滑块

### 共享队列面板

- 播放详情右侧全高 `endDrawer`，当前项高亮、点击切歌

### 平台适配

- Android `minSdk` 21 → 24（`just_audio` 要求）
- Android 真机（SM-N986U / Android 13）验证通过：`musicUrl` 取链 → 播放 → seek
- 三端 Debug 构建通过（APK / IPA / unsigned HAP）

## [0.1.0] - 2026-07-15

### 项目初始化

- 创建 iOS、Android、鸿蒙三端 Flutter 工程
- 统一包名 `com.coral.music.mobile`
- 建立 Material 3 珊瑚主题（种子色 `#ff6f61`），跟随系统明暗模式
- 配置代码格式检查、静态分析与单元测试流程
- 确立开发历史与文档制度

### 工程基础设施

- 搭建 Go Router 九入口路由与 Shell 路由架构
- 实现底部主导航栏（手机）与侧边 NavigationRail（宽屏 >=720px）
- 实现更多页面入口与占位页面体系
- 建立 Riverpod 状态管理框架
- 引入 `flutter_riverpod`、`go_router`、`dio`、`crypto`、`pointycastle` 核心依赖

### 领域模型

- 定义 `OnlineSource` 枚举：酷我、酷狗、QQ、网易云、咪咕
- 定义 `TrackSourceKind` 枚举：`online`、`local`、`download`、`webdav`
- 定义 `AudioQuality` 音质降级链路：master → atmos_plus → atmos → hires → flac24bit → flac → 320k → 192k → 128k
- 实现 `Track` 不可变歌曲实体（含 id、来源、标题、歌手、专辑、时长、封面等字段）
- 实现 `PageResult<T>` 通用分页结果类型
- 实现 `LeaderboardBoard` 榜单定义类型

### 网络层

- 建立 Dio HTTP 客户端工厂，配置移动端 User-Agent 与 15s 超时
- 实现 `mapDioException` 异常映射：cancelled / timeout / noNetwork / badResponse / invalidData / unknown
- 实现 `AppFailure` 异常类，含稳定 code、用户文案与脱敏诊断信息

### 酷我音乐 API 集成

- 实现 AES-ECB + PKCS7 请求加密与响应解密
- 实现 MD5 签名查询字符串构建

### 排行榜

- 对接酷我音乐 12 个榜单：飙升榜、新歌榜、热歌榜、抖音热歌榜、热评榜、ACG新歌榜、经典怀旧榜、华语榜、粤语榜、欧美榜、韩语榜、日语榜
- 实现榜单目录展示、榜单详情分页查询
- 实现音乐源下拉选择（当前仅酷我）
- 实现横向滑动 ChoiceChip 榜单选择器
- 实现歌曲列表展示（封面、标题、歌手、时长）
- 实现上/下翻页与下拉刷新
- 实现"播放全部"替换队列及单曲点击播放
- 使用 requestId 机制防止异步请求竞态

### 歌曲搜索

- 对接酷我音乐歌曲搜索 API
- 实现搜索结果列表与分页展示
- 实现搜索输入框与搜索按钮
- 使用 requestId 机制防止搜索请求乱序

### 播放队列

- 实现 `PlaybackQueueState` 不可变队列状态
- 实现 `PlaybackQueueController` 队列管理
- 支持 `replaceQueue`（替换队列）与 `select`（切歌）
- 支持 contextId 追踪队列来源

### 迷你播放栏

- 实现底部常驻迷你播放栏（位于内容区与导航栏之间）
- 显示当前歌曲信息或"未在播放"占位状态
- 播放按钮仅 UI 占位，音频引擎将在播放器阶段接入

### 受限 / 阻塞项

- **酷狗排行榜可行性验证 (BLOCKED)**：酷狗 HTTP 端点正常，但同主机 HTTPS 请求因证书主机名不匹配失败；保持三端安全边界，等待具备正确 TLS 证书的官方端点后再恢复
- **三端真机验证 (BLOCKED)**：Flutter doctor 仅发现 macOS 与 Chrome，未发现三端真机，平台能力不得在真机验证前标记完成
- **鸿蒙调试签名 (待配置)**：已可构建 unsigned HAP，需 DevEco 配置调试签名后安装到真机
- **iOS Platform Runtime (待安装)**：Xcode/CocoaPods 已完成，缺少 iOS 26.5 Platform Runtime
