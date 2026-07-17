# 珊瑚音乐移动端架构

## 目录

- [技术基线](#技术基线)
- [工程结构](#工程结构)
- [领域模型](#领域模型)
- [数据与服务边界](#数据与服务边界)
- [平台能力](#平台能力)
- [关键数据流](#关键数据流)
- [安全与商店约束](#安全与商店约束)
- [质量边界](#质量边界)

## 技术基线

- iOS/Android：Flutter 稳定能力；鸿蒙：OpenHarmony Flutter 发行版。
- 当前可用候选为 Flutter `3.27.5-ohos-0.1.1-Beta3`、Dart `3.6.2`、OpenHarmony API 18；Phase 0 完成前不得称为正式锁定版本。
- UI 使用 Material 3 和珊瑚主题；状态使用 Riverpod；路由使用 `go_router`；HTTP 使用 Dio；关系数据使用 SQLite。
- 设置使用轻量键值存储，凭据使用 Keychain/Keystore/Asset Store 等系统安全存储。
- iOS/Android 音频先验证 `just_audio + audio_service`；鸿蒙无兼容插件时用 MethodChannel 对接 AVPlayer/AVSession。
- 不使用 Freezed、Drift 等代码生成方案；Dart sealed class、record、enum 和手写映射足够覆盖首发模型。

所有插件必须在三端小样验证后才能进入正式 `pubspec.yaml`。插件没有鸿蒙实现时，先判断系统 API 是否可用；只有音频、媒体会话、后台下载、脚本沙箱和安全存储允许维护平台适配。

## 工程结构

```text
lib/
  app/                 # 启动、主题、路由、应用壳
  core/                # 稳定的错误、HTTP、数据库、日志能力
  domain/              # 跨功能实体、值对象和纯 Dart 规则
  features/
    search/
    song_list/
    leaderboard/
    list/
    favorites/
    library/
    player/
    download/
    webdav/
    settings/
  platform/            # MethodChannel 客户端与平台能力类型
  l10n/
ios/
android/
ohos/
test/
integration_test/
```

每个 feature 最多按 `data/`、`state/`、`view/` 分层。只有数据来自多种实现时才定义 repository 接口；UI 不直接访问 SQLite、Dio 或 MethodChannel。

## 领域模型

### Track

```dart
enum TrackSourceKind { online, local, download, webdav }

enum AudioQuality {
  master,
  atmosPlus,
  atmos,
  hires,
  flac24bit,
  flac,
  high320k,
  high192k,
  standard128k,
}

final class Track {
  const Track({
    required this.id,
    required this.sourceKind,
    required this.sourceId,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.coverUri,
    this.localUri,
    this.extra = const {},
  });
  final String id;
  final TrackSourceKind sourceKind;
  final String sourceId;
  final String title;
  final String artist;
  final String? album;
  final Duration? duration;
  final Uri? coverUri;
  final Uri? localUri;
  final Map<String, Object?> extra;
}
```

`id` 使用稳定的 `sourceKind:sourceId:sourceTrackId`。不得用标题和歌手作为主键。

### Playback

- `PlaybackQueue`：队列 ID、不可变歌曲列表、当前索引、来源上下文。
- `PlaybackMode`：`listLoop`、`singleLoop`、`shuffle`。
- `PlaybackSnapshot`：当前 Track、位置、时长、播放状态、实际音质、错误、更新时间。
- `LyricPayload`：原文、逐字歌词、翻译、罗马音、来源和偏移。
- 音质降级顺序集中定义一次；本地、下载和 WebDAV直接拒绝该策略。

### Lists and library

- `UserPlaylist`：ID、名称、类型、排序位置和更新时间。
- `FavoritePlaylist`：来源、稳定歌单 ID、名称、封面、作者、描述和最近导入的曲目快照；仅存本地，不与服务端同步。
- `PlayHistoryEntry`：Track 快照、最近播放时间、次数和最后位置。
- `FavoriteSongList`、`FavoriteAlbum`：保留在线实体快照，来源不可用时仍能显示。
- `DownloadTask`：状态、进度、目标 URI、临时 URI、错误、重试次数和 Track 快照。
- `WebDavAccount`：公开元数据不含密码；凭据使用相同 ID 存放安全存储。

### User API

- `SourcePluginManifest`：ID、名称、版本、支持来源、动作、音质、脚本哈希和签名状态。
- `SourcePluginRequest`：请求 ID、动作、来源、输入和截止时间。
- `SourcePluginResponse`：请求 ID、结果或归一化错误；限制最大响应大小。
- 兼容动作只包含桌面协议已经使用的 `musicUrl`、`lyric`、`pic` 等，不为未来动作预留抽象。

## 数据与服务边界

SQLite 使用显式版本迁移，至少包含：

- `user_playlists`、`playlist_tracks`、`playlist_order`
- `play_history`、`favorite_songlists`、`favorite_playlists`、`favorite_albums`
- `lyric_cache`、`edited_lyrics`、`music_url_cache`、`other_source_cache`
- `download_tasks`、`dislike_rules`
- `webdav_accounts`，仅保存非敏感字段和安全凭据引用

写事务完成后再更新 Riverpod 状态。迁移失败不得清库：保留原文件、记录脱敏错误并提供备份导出。

服务最小集合：

- `OnlineCatalogService`：搜索、歌单、榜单和详情归一化。
- `PlaybackResolver`：按来源解析可播放 URI。
- `LyricService`：本地候选、缓存、在线获取、解析和时间轴。
- `LibraryService`：列表、历史、收藏、分类和不感兴趣规则。
- `DownloadCoordinator`：以 Track 快照和选定音质创建本地下载任务，协调持久状态与平台后台执行；歌单下载全部只展开当前歌单快照，不追踪远端更新。
- `WebDavService`：用户配置的鉴权、PROPFIND、Range GET 和路径归一化。

## 平台能力

```dart
abstract interface class AudioEngine {
  Stream<PlaybackSnapshot> get snapshots;
  Stream<AudioEngineCommand> get commands;
  Future<void> load(Track track, Uri uri, {Duration? startAt});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
}

abstract interface class SourcePluginRunner {
  Future<SourcePluginManifest> inspect(String script);
  Future<SourcePluginResponse> execute(SourcePluginRequest request);
  Future<void> dispose();
}

abstract interface class BackgroundDownloadService {
  Stream<PlatformDownloadEvent> get events;
  Future<String> enqueue(DownloadRequest request);
  Future<void> pause(String id);
  Future<void> resume(String id);
  Future<void> cancel(String id);
}
```

平台层只交换可序列化值，不传递 Widget、Riverpod provider 或数据库对象。MethodChannel 错误统一映射为稳定错误码。

## 关键数据流

### 在线播放

`歌曲点击 -> PlayerController -> PlaybackResolver -> URL 缓存 -> User API/在线取链 -> 音质降级 -> AudioEngine（含系统媒体处理器） -> PlaybackSnapshot`

- URL 成功后异步补齐封面和歌词。
- 只对明确的“音源未找到/地址失效”重试一次；鉴权、权限和格式错误不盲目换源。

### 本地播放

`文件选择 -> 扩展名过滤 -> 元数据读取 -> Track(local) -> 同目录歌词 -> AudioEngine`

- 不调用在线取链或 User API 歌词；只读取受支持的本地歌词来源。
- 目录访问权限失效时提示重新授权，不删除列表记录。
- B5-11 必须完成“文件/分享导入或用户授权目录递归扫描 -> SQLite 去重 -> 列表/队列 -> 前后台播放与 seek -> 历史/恢复”的同一纵向链路；不做静默全盘扫描。

### WebDAV

`用户配置账号安全凭据 -> PROPFIND -> Track(webdav) -> 带鉴权 Range GET -> AudioEngine`

- 不提供项目服务器、同步或账号服务；仅直连用户配置的 WebDAV 文件源。
- 日志只记录账号 ID、主机和状态码，不记录用户名之外的凭据。
- 401/403 立即停止重试并请求用户重新验证。

### 下载

`创建持久任务 -> 解析 URI -> 平台后台任务 -> 进度事件 -> SQLite -> UI`

- 应用进程重启后以平台任务状态为准进行协调。
- 临时文件完成并校验后原子移动到目标位置，避免把半文件标记完成。

## 安全与商店约束

- User API 脚本运行在独立 WebView/JavaScript 上下文，无 Node、文件、剪贴板、定位或任意原生桥。
- 网络请求只能通过受控代理消息发起，校验 URL scheme、超时、响应大小和重定向次数。
- 公共商店构建只允许政策审核通过的动态导入方式；否则隐藏导入入口，仅保留签名内置源。
- 所有凭据日志字段使用固定掩码；备份默认不导出凭据。
- 不建设项目自有的服务器存储、跨设备同步和局域网服务；WebDAV 只连接用户自行配置的文件源，备份仅导入/导出本地文件。
- 权限按使用时请求；拒绝后仍能使用不依赖该权限的功能。

## 质量边界

- Domain 和状态逻辑必须是纯 Dart 可测代码。
- UI 列表使用惰性构建，1000 项操作不得同步扫描元数据或文件。
- 搜索、详情和分页请求按 key 去重；离开页面可取消，不让旧响应覆盖新状态。
- 错误对象包含稳定 code、用户文案和脱敏诊断信息。
- 三端插件版本固定，不使用浮动 git 分支；升级单独验证 HAP、APK 和 iOS 构建。
