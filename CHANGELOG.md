# Changelog

All notable changes to 珊瑚音乐移动端 (Coral Music Mobile) will be documented in this file.

## [1.0.0] - 2026-07-20(03)

### 列表动作反馈与子页面返回

- 新增 `DownloadTrackButton`：推荐/搜索/歌单/队列统一显示空闲/下载中/已下载图标并反馈加入/重复/已下载
- `FavoriteTrackButton` 点击即乐观切换实心/空心心形，阻止重复提交，收藏/取消后显示 SnackBar
- "我的"四个快捷入口统一使用 `push` 保留系统返回栈；新增 `AppBackScope`/`AppBackButton` 处理无栈时回到"我的"

### 歌单广场滚动加载更多

- 移除底部上一页/页码/下一页控件，改用 `SliverGrid` 惰性构建
- 距底部少于 320px 自动加载下一页，跨页按 `source + playlist id` 去重
- 来源/排序/标签/搜索/下拉刷新仍从第 1 页重新加载

### 播放模式切歌修复

- 完成事件重复快照只推进一次：先切到 `completed` 状态再推进队列
- `replaceQueue()` 保留当前 `PlaybackMode`，随机历史随新队列重置
- 随机模式手动上一曲/下一曲复用 `_selectShuffle()` 选择非相邻候选

### 启动时恢复音源

- 应用根 `initState()` 主动创建 `userApiDebugProvider`，不再依赖用户先进入设置页
- 冷启动即恢复持久化 HTTPS 音源并可直接播放在线歌曲

### 下载按钮即时状态

- `DownloadTrackButton` 带本地提交态，不等待下载控制器恢复即显示加载动画
- `queued/downloading` 显示加载动画，`paused` 显示暂停，`completed` 显示勾
- 播放详情删除独立下载动作，统一观察 `downloadProvider`

### 每日推荐与音乐电台

- 每日推荐按当前来源和本地日期稳定选择一个真实榜单并加载歌曲
- 原"排行榜"快捷入口改为"音乐电台"：从推荐曲库过滤不感兴趣后建立随机队列并立即播放

### 首页顶部菜单

- 平台选择使用 Material 3 `MenuAnchor` 替换下拉框，显示图标和当前选中状态
- 铃铛按钮显示锚定消息面板，无消息数据时显示"暂无新消息"

### Android 1.0.0 APK

- `pubspec.yaml` 更新为 `1.0.0+1`
- Release APK 构建待审批服务恢复后执行（当前被 HTTP 503 拦截）

## [1.0.0] - 2026-07-20(02)

### 咪咕歌单广场与详情

- 新增 `MiguPlaylistService`：推荐/按标签广场、递归收集嵌套歌单、兼容旧 `contentItemList` 响应
- 来源菜单加入咪咕；QQ/咪咕明确禁用无安全实现的歌单关键词搜索

### 本地专辑收藏快照

- SQLite v11 新增 `album_favorite` 表，`FavoriteAlbum` 以本地稳定 key 保存专辑名/歌手/封面/曲目快照
- 专辑分类详情新增收藏/取消按钮，收藏页新增"收藏专辑"分区可离线播放
- 本机备份 v1 增加可选 `favoriteAlbums` 字段，旧备份兼容

### 本机缓存管理

- 设置页提供真实缓存占用和清理：清除嵌入封面文件与会话播放 URL 缓存
- 不删除下载、列表、收藏、音源凭据或 WebDAV 账户

### 播放页操作收口

- 播放详情拆分为独立文件（播放控制/操作弹层/歌词/队列）
- 收藏与操作统一 48px 图标槽；移除两处重复应用音量入口
- 下载首次入队等待持久化恢复完成，显示成功/重复反馈
- 音质选择改为可滚动底部面板

### 搜索发现数据修复

- 热词改用 QQ MusicU `GetHotkeyForQQMusicPC` HTTPS 请求，删除旧酷我热词服务
- 固定推荐歌手使用 QQ 歌手 MID 的 HTTPS 头像，加载失败保留渐变兜底
- 搜索发现区提取为 `search_discovery.dart`

### 歌词兜底与重试反馈

- 酷我内置歌词失败不再终止链，User API 继续尝试
- 会话内成功歌词缓存（FIFO 20 首），刷新失败返回上次成功结果
- 空本地 LRC 不再阻断在线源；重试使用 `ref.refresh` 并显示加载和 SnackBar 反馈

### 播放页滑动导航

- 播放与歌词改为同一 `PageView` 相邻页面：左滑进入歌词，右滑返回
- 播放页顶部向下拉超过 80px 阈值退出详情页
- 歌词页纵向滚动和非顶部滑动不触发退出

### 下载音质展示与升级

- 下载项显示最终文件名、大写扩展名和音质标签
- 已完成任务存在更高可用音质时允许选择升级重下
- 同曲已有任务全部完成且新音质严格更高时才入队，旧文件保留

### 歌词页分区布局

- 歌词页改为固定三段式：顶部小封面/歌名/歌手，中部独立滚动歌词，底部固定进度/时间/主控
- 新增 `PlayerTransportControls`，播放页与歌词页共享传输控制
- 歌词字号收紧为 `titleMedium`，当前行保持珊瑚色逐字高亮

### 播放器跳转应用壳红屏修复

- 播放器 Snackbar"查看下载"由 `push` 改为 `go`，避免重复构建壳导航触发红屏
- 播放错误"去导入音源"同步改为 `go('/setting/source')`
- 设置页内部同壳导航保持 `push` 保留系统返回栈

## [1.0.0] - 2026-07-20(01)

### 底栏页面切换稳定性

- 路由改用 `StatefulShellRoute.indexedStack` + `NoTransitionPage`，修复底栏切换文字叠帧和状态丢失
- 首页/搜索/"我的"各自保活

### 在线歌单收藏快照

- SQLite schema v4 新增 `online_playlist_favorite` 表，保存歌单元信息和曲目 JSON 快照
- 歌单详情新增收藏按钮，"我的收藏"可离线播放和移除收藏歌单

### 在线歌曲下载队列

- 新增 `DownloadTask`/`DownloadStatus`、下载控制器和下载页
- Dio 下载到应用私有目录，支持暂停/Range 续传/取消/重试/离线播放
- SQLite v5 持久化任务状态，重启后未完成任务安全转为"已暂停"
- 歌单详情新增"下载全部"，固定快照、去重、单曲失败不停止其余
- 下载文件命名 `歌名 - 歌手.扩展名`，重名自动加后缀不覆盖

### 本地音频导入与播放闭环

- 新增 `LocalAudioScanner` 支持文件/目录递归扫描和扩展名过滤
- 同目录封面发现、LRC/CUE 旁路识别、MP3/FLAC/M4A/Ogg/Opus/WAV 嵌入标签读取（纯 Dart）
- CUE 单文件分轨播放：读取 FILE/TRACK/INDEX 生成分轨起止毫秒，按边界自动切歌
- 已下载歌曲进入本地媒体库：完成且文件存在的下载任务合并为 `download` 本地 URI Track

### WebDAV 远程媒体

- PROPFIND 目录客户端、音频格式识别和 Track 转换
- 凭据通过 `flutter_secure_storage` 保存，播放时运行期传递 Authorization
- 目录本地关键词筛选和上级目录导航（纯 URI 逻辑拒绝越界）
- WebDAV 下载复用 B6-01 的 `.part` 原子写入和 Range 续传
- 多账号管理：非敏感账户索引 JSON 编解码，支持多账户保存/切换/删除
- 面包屑导航：根目录到当前目录转为可点击 URI 层级
- WebDAV 音频行新增"添加到我的列表"入口

### 音乐分类

- 音乐分类页提供历史/艺术家/专辑/类型/年份五个页签
- 类型/年份读取真实 `Track.extra` 标签

### 定时停止

- `PlayerController` 维护会话内截止时间和"当前曲结束后停止"状态
- 播放详情新增 15/30/45/60 分钟和当前曲结束的定时入口

### 有效设置入口

- "设置"与"音源管理"拆分为独立路由，设置页只导航到已有真实能力

### 列表导入导出与重复检测

- `PlaylistTransferCodec` 兼容桌面端 `playListPart_v2` 格式，支持单列表 JSON 导入/导出
- 导入显示新增和跳过数量，导出不包含凭据
- `findDuplicateTrackIds` 规范化歌名/歌手/专辑/时长后检测重复，列表详情增加"识别重复歌曲"入口

### 本地资料备份与恢复

- `coralMusicMobileBackup_v1` 格式备份用户列表/收藏/歌单收藏/不感兴趣规则
- 恢复前统计预览和二次确认，单 SQLite 事务合并恢复不覆盖现有数据

### 不感兴趣规则

- SQLite v7 新增 `ignored_track` 表保存曲目 id 快照；播放详情新增"不喜欢"切换
- "播放全部"建队列前过滤命中曲目，单曲点击不受影响
- SQLite v8 新增 `ignored_keyword` 表，关键词去空格小写化去重；`filterIgnored` 同时过滤 ID 和关键词

### 主题模式持久化

- `ThemeModeController` 使用安全存储保存 `system/light/dark`，跨启动恢复
- 模块边框改为 `ColorScheme.outlineVariant`，深浅色自动适配

### User API HTTPS 来源恢复

- `UserApiSourcePreferences` 使用安全存储保存来源名称和地址
- 启动后自动恢复并重新下载加载脚本，不持久化脚本内容

### 播放队列持久化

- SQLite v9 新增 `playback_queue` 表存曲目快照/索引/模式/上下文
- 队列 provider 串行写入状态，恢复不自动播放也不覆盖启动期间用户操作

### 深链注册与路由归一化

- Android/iOS/鸿蒙三端注册 `coralmusic://` scheme
- `go_router` 统一识别 `coralmusic:///player` 与 `coralmusic://player` 等不同写法
- 未知深链安全回落排行榜

### 系统分享音频导入

- Android 注册 `audio/*` 的 `ACTION_SEND`/`ACTION_SEND_MULTIPLE`，URI 复制到应用私有目录
- 导入动作移到应用根部，由 `LibraryController` 统一创建/复用"分享导入"列表并去重

### 下载文件系统导出

- 已完成下载项新增"导出文件"入口，复用 `file_picker` 选择目标路径后直接复制

### 搜索历史与综合搜索

- SQLite v10 新增搜索关键词表，按最近时间截断为 20 条；空搜索页展示"最近搜索"Chip
- 综合搜索模式并行请求酷我/网易云/咪咕三来源，逐项展示来源标签
- QQ 音乐搜索：`QqCatalogService.searchTracks()` 向 `musicu.fcg` 发送桌面端同模块 JSON 请求
- 酷狗音乐搜索：新增 `KugouCatalogService` 请求 `song_search_v2`，展开 `Grp` 去重，各音质 hash 存入 `Track.extra`
- 综合搜索扩展为五来源并行

### 默认播放音质设置

- `DefaultQualityController` 安全持久化默认音质（默认 SQ FLAC）
- `PlayerController` 使用偏好选择自动取链质量，手动切换仍优先

### 排行榜卡片溢出修复

- 横向榜单卡高度从 124 调整为 142，修复窄高约束下 RenderFlex 溢出

### Flutter 与 Android CI

- GitHub Actions 工作流执行格式检查/静态分析/单元测试/Android Debug 构建
- 修复队列恢复在无 SQLite 环境的异常和安全存储不可用时的降级

## [1.0.0] - 2026-07-17(04)

### 在线歌曲收藏入口

- 新增 `FavoriteTrackButton` 组件，复用 `LibraryController` 的 `favorites` 列表状态
- 搜索、排行榜、歌单详情和播放详情统一接入收藏/取消收藏操作
- `favoriteRevision` 递增确保按钮即时刷新

### TDesign 移动端规范迁移

- 因 `tdesign_flutter` 缺乏鸿蒙兼容性，决定使用 Flutter Material 组件实现 TDesign 视觉规范
- `app_theme.dart` 统一 ColorScheme 和控件圆角（8pt 圆角、中性表面、状态色）
- 经多轮真机回归，从灰白毛玻璃改为珊瑚暖白视觉，重写首页/搜索/我的/播放器/歌单/设置等页面

## [1.0.0] - 2026-07-17(03)

### 范围修订：本地优先、无服务器

- 移除评论、跨设备同步、OpenAPI/局域网服务及相关发布验收任务
- 保留在线音乐检索与播放、受限 User API、本地 SQLite、本地文件、应用目录下载、用户自配 WebDAV 和本地文件备份
- WebDAV 明确为"用户自行配置的远程文件源"，不提供账号、同步或数据托管
- 备份仅保留本地文件导入/导出，不上传至项目或局域网服务器

### 计划修订：本地音频导入与播放闭环

- 新增 B5-11 纵向任务：系统文件选择器选文件/目录、递归扫描、元数据解析、入库、播放、歌词、后台恢复
- 目录扫描仅访问用户显式授权位置，不做静默全盘扫描
- 本地曲目 `PlaybackResolver` 直连 `localUri`，不调用 User API 或在线取链
- 复用 `AudioEngine`、MediaSession、进度保存和同目录歌词

### 计划修订：在线收藏与下载

- B5-12：在线歌曲收藏入口，复用 `favorites` 列表状态
- B5-13：在线歌单收藏，SQLite 保存来源、歌单 ID、名称、封面和曲目快照
- B6-01：在线歌曲下载队列，临时文件校验后原子写入应用下载目录，支持暂停/恢复/重试/取消/进程恢复
- B6-02：歌单下载全部，固定当前快照、去重、并发排队、单曲失败不停止其余

## [1.0.0] - 2026-07-17(02)

### 在线封面与歌词服务补全

- 酷我搜索解析补齐 `web_albumpic_short`，生成可访问 CDN 封面地址
- 播放队列和播放详情复用同一封面
- 歌词请求移除 manifest `lyricSources` 门控，改为已启用在线音源的受限尝试，失败返回空歌词且不影响播放
- 播放详情显示当前质量与码率

### 播放音频文件信息探测

- 新增 `audio_file_probe.dart`：64KB Range 请求，解析 MP3 ID3/帧头和 FLAC STREAMINFO
- 播放详情显示 `kbps · kHz · 容器格式 · 档位`，探测失败仅显示质量标签（不再伪回退规格）
- SQ 语义修正：SQ = FLAC 无损，HQ = 320 kbps
- FLAC 实际平均码率：从 `Content-Range` 总字节数与 STREAMINFO 总采样数计算
- MP3 ID3 跳过偏移修正（`10 + size`）与 MPEG Layer I/II/III 码率表修正
- 副信息层级调整：副标题为"歌手 · 专辑"，文件信息行仅 `kbps · kHz · 格式 · 档位`
- 真机验证：《晴天》显示 `1643 kbps · 44 kHz · FLAC · SQ`

### iOS 受限 User API 运行时

- 新增 `ios/Runner/UserApiRunner.swift`，WKWebView 实现 `load`/`clear`/`resolveMusicUrl`/`resolveLyric`
- 原生 `URLSession` 执行脚本请求（HTTPS only、GET/POST、无重定向、64KB 请求体、1MB 响应）
- 受限 bridge 加入同步 JS MD5（`lx.utils.crypto.md5`），AES/RSA/zlib 仍拒绝
- `flutter build ios --no-codesign` 编译通过；iOS Platform Runtime/真机验收待补

### 启动恢复最近播放曲目

- `PlayerController.restoreLastPlayback()` 从历史恢复最近曲目（`idle` 状态，不触碰音频引擎）
- 用户首次 `toggle()` 才走取链并 seek 到保存位置
- 在线曲目恢复后无音源时提示"请先导入音源"，播放详情提供"去导入音源"直达入口

### 音频引擎重复错误去重

- 按 `Track.id + AudioQuality` 去重，`load()` Future 异常与 `errorStream` 同次错误只处理一次
- 引擎加载错误使用 User API 实际返回的质量（而非用户请求的质量）进行降级

## [1.0.0] - 2026-07-17(01)

### 音源 URL 导入优先与详情卡

- HTTPS URL 导入提升为页面首要操作，手动脚本粘贴收入"高级导入"折叠区
- 导入成功后展示音源详情卡：名称、描述、版本、作者、主页、来源地址及中文能力标签
- 解析脚本顶部公开 JSDoc 声明（`@name`/`@description`/`@version`/`@author`/`@homepage`），不扩展平台桥接

### 播放详情主控布局

- 上一曲/播放/下一曲固定为视觉居中的主控行，模式按钮移至独立次级行
- 窄屏下主播放键不再因模式按钮偏移

### 会话内音源管理导航修复

- "我的 → 设置/音源管理"改为 `context.push`，系统返回不再结束 Activity
- 同一会话重新导入后能力卡仍可见，新增 `test/more_page_test.dart` 覆盖返回栈

### User API 歌词契约回归

- 新增桌面兼容 `{ data: { lyric, lxlyric, tlyric, rlyric } }` 包装对象的归一化契约测试

## [1.0.0] - 2026-07-16(04)

### 列表歌曲批量操作

- 长按进入选择模式，支持批量删除（SQLite 事务）、复制/移动到另一列表（目标按 Track ID 去重）、批量置顶
- 列表歌曲拖动排序（`ReorderableListView`），全量 `position` 回写；筛选/批量模式下禁用拖拽

### User API 音源管理

- `UserApiDebugController` 维护会话内脚本、名称、声明能力和当前启用项；一次只激活一个脚本
- `UserApiRunner` 新增 `clear` 平台边界，移除当前音源时取消在途请求并清空原生运行时
- 设置页改为"音源管理"：粘贴/HTTPS 地址导入、启用切换、能力展示、移除
- 空白脚本立即返回错误，不启动 WebView 初始化

### 在线取链缓存与降级

- `PlaybackResolver` 以歌曲 ID + 音质为键缓存 15 分钟 HTTPS URL，提供 `forceRefresh`/`invalidate`
- 引擎失败清缓存并仅重试一次取链，第二次失败才进入跳过逻辑
- 高音质刷新失败后按 `AudioQuality` 枚举顺序降级到下一已声明质量
- 非在线来源（本地/下载/WebDAV）直接返回 `localUri`，不查询 User API

### 播放进度恢复

- 每 15 秒/暂停/seek 保存位置到 `play_history.last_position_ms`，播放完成清零
- 播放历史点击从有效位置继续播放，少于 5 秒或接近结尾从头开始
- 串行执行同一播放器的历史写入，修复首次播放后立即 seek 的竞态

### User API 歌词

- Android `UserApiRunner` 增加独立 `resolveLyric` 回调，与 `musicUrl` 隔离
- 标准 LRC 时间轴解析，当前行高亮、翻译、罗马音对齐
- LX 逐字歌词（`<start,duration>` 标签）优先，保留词间空格
- 支持 `[offset:±ms]` 标签，原文行与 LX 词片段使用同一偏移
- 歌词自动滚动到当前行

### 本地 LRC 优先

- 本地 `file://` 曲目先读取同目录 LRC（四种命名候选），未命中才走 User API
- 本地/下载/WebDAV 在 LRC 未命中时返回空歌词，不调用 User API

### User API HTTPS 地址导入

- 流式 HTTPS 下载器，响应长度限制 256 KiB，严格 UTF-8 解码
- 禁止重定向，HTTP/超大脚本拒绝

### 后台播放运行时

- 引入 `audio_service 0.18.19`，`JustAudioEngine` 将 `just_audio` 实例放入 `AudioService` 统一处理器
- Android 声明前台媒体服务与媒体按钮接收器，iOS 声明 `UIBackgroundModes/audio`
- `AudioEngineCommand` 将系统上一首/下一首路由到 `PlaybackQueueController`
- 旧 Android `MediaSessionBridge` 已删除，避免重复会话
- Android 真机（SM-N986U）播放态验收：会话 `PLAYING`、元数据发布、HOME 后后台持续播放、`KEYCODE_MEDIA_PLAY_PAUSE` 控制
- 空闲会话策略：service/receiver 默认 disabled，首次真实 load 前才启用

### 快速切歌旧请求隔离

- `PlayerController` 持有单调请求序号，新请求使旧请求失效
- 取链、加载、seek、播放和失败映射前均校验当前请求

### LX 音源运行时兼容

- 对齐桌面 `preload.js` 协议：`lx.utils.crypto`（MD5/随机字节）、`currentScriptInfo.rawScript`、JSON 响应同时放入 `response.body` 与回调参数
- 播放结果接受 `http/https`（有主机名、≤8192），脚本下载仍仅 HTTPS
- Android `usesCleartextTraffic` 开启，仅作用于最终媒体地址
- 真机闭环通过：LX URL 导入 → 取链 → 实际播放 → 后台持续 → 媒体键控制

### 高保真 UI 重构

- **UI-01**：主题扩展（薄荷/天空蓝/薰衣草/粉色/紫色），四项主导航（首页/发现/播放/我的），迷你播放栏圆角半透明卡片
- **UI-02**：首页改为推荐布局——渐变主推荐卡、横向榜单卡、真实歌曲圆角行
- **UI-03**：搜索页圆角搜索框、热搜排名、歌手建议卡、圆角结果列表
- **UI-04**：播放详情渐变唱片封面、紫色圆形主按钮、居中渐隐歌词
- **UI-05**：我的页面用户卡片、快捷功能网格、分组设置卡
- **UI-06**：桌面端图标迁移到三端（Android/iOS/鸿蒙）
- **UI-02 补**：关闭 `extendBody` 修复迷你播放栏与 Navbar 重叠（真机 UI Automator 验证通过）

## [1.0.0] - 2026-07-16(03)

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

## [1.0.0] - 2026-07-16(02)

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

## [1.0.0] - 2026-07-16(01)

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

## [1.0.0] - 2026-07-15

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
