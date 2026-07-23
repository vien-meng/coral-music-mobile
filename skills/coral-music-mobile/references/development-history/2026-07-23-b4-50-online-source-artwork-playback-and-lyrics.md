# B4-50 多音源封面、播放与歌词链路修复

状态：DONE

## 目标

- 修复酷狗歌单详情播放失败（"歌曲不存在"）。
- 修复歌单详情页/专辑详情页返回键跳错页面。
- 修复酷我歌单详情封面逐个消失。
- 修复酷我搜索结果歌曲与专辑列表缺封面。
- 修复酷狗搜索结果/专辑播放提示"歌曲不存在"。
- 修复咪咕歌单详情页歌曲列表缺封面。
- 优化歌词加载慢和失败（串行多请求 + 长超时）。
- 新增播放页进入时缺封面就单独请求当前歌曲封面的兜底机制。

## 根因与修复

### 1. 酷狗歌单详情播放失败

- **根因**：`kugou_playlist_service.dart` 的 `_track` 方法把 `audio_id`（数字型音频 ID）作为 `sourceTrackId` 和 `extra['songId']`。`_legacyMusicInfo` 优先取 `extra['songId']` 传给 JS 脚本，脚本用数字 ID 调酷狗取链接口失败。排行榜能用是因为它直接用 `hash` 作为 ID。
- **修复**：`lib/features/song_list/data/kugou_playlist_service.dart` 的 `_track` 方法：
  - `sourceTrackId` 从 `"${item['audio_id'] ?? hash}"` 改为 `hash`。
  - 移除 `extra['songId']`，让 `_legacyMusicInfo` 回退到 `sourceTrackId = hash`。

### 2. 歌单详情页返回键跳到首页

- **根因**：歌单详情和歌单广场是同一个 `SongListPage` 内通过 `state.detail` 切换的，不是独立路由。Android 系统返回键默认会 pop 整个 `SongListPage` 回首页。
- **修复**：`lib/features/song_list/view/song_list_page.dart` 的 `build` 方法用 `PopScope` 包裹：
  - `canPop: !hasDetail` — 详情页时禁止默认 pop。
  - `onPopInvokedWithResult` — 拦截系统返回键，调用 `closeDetail()` 返回歌单广场。

### 3. 酷我歌单详情封面逐个消失

- **根因**：`kuwo_playlist_service.dart` 的 `_trackCover` 只读 `albumPic`（驼峰），API 返回 `albumpic`（全小写），匹配不到，初始 `coverUri = null`。之后异步搜索封面时，搜索接口返回的结果可能不准确或加载失败，每解析完一首就 setState 重建列表，造成"封面逐个消失"的视觉效果。
- **修复**：`lib/features/song_list/data/kuwo_playlist_service.dart` 的 `_trackCover` 方法增加读取 `albumpic`（全小写）字段。字段优先级：`pic` → `albumpic` → `albumPic` → `web_albumpic_short`。

### 4. 酷我搜索结果歌曲与专辑列表缺封面

- **根因**：`kuwo_search_parser.dart` 的 `_cover` 只读 `web_albumpic_short` 单一字段，无 `pic`/`albumpic`/`albumPic` 回退。专辑封面取首歌曲封面，搜索结果缺封面则专辑也缺。
- **修复**：`lib/features/search/data/kuwo_search_parser.dart` 的 `_cover` 方法改为接收 `Map<String, Object?> item`，增加 `pic`/`albumpic`/`albumPic` 字段回退，与歌单服务保持一致。

### 5. 酷狗搜索结果/专辑播放提示"歌曲不存在"

- **根因**：与酷狗歌单详情问题相同。`kugou_search_parser.dart` 把 `Audioid`（数字型音频 ID）作为 `sourceTrackId` 和 `extra['songId']`。JS 脚本用数字 ID 调酷狗取链接口失败。
- **修复**：`lib/features/leaderboard/data/kugou_search_parser.dart` 的 `_appendTrack` 方法：
  - `sourceTrackId` 从 `audioId.isNotEmpty ? audioId : hash` 改为 `hash`。
  - 移除 `extra['songId']`。
  - 去重 key 从 `'$id:$hash'` 简化为 `hash`。

### 6. 咪咕歌单详情页歌曲列表缺封面

- **根因**：咪咕 API 返回的 `img1`/`img2`/`img3` 是根相对路径（`/data/oss/...`，单 `/` 开头，无 host）。`_httpsUri` 仅处理 `//` 开头的协议相对路径和完整 URL，对单 `/` 开头的路径因 `host.isEmpty` 直接丢弃。
- **修复**：`lib/features/song_list/data/migu_playlist_service.dart` 的 `_httpsUri` 方法增加对根相对路径的处理，补上咪咕图片 host `https://d.musicapp.migu.cn`。

### 7. 专辑详情页返回键跳到歌单广场

- **根因**：`SearchAlbumDetailPage` 用 `Navigator.pop()` 返回，但系统返回键可能绕过自定义返回按钮逻辑，且 `StatefulShellRoute` 分支切换时路由栈可能混入歌单详情。
- **修复**：`lib/features/search/view/search_album_detail_page.dart` 的 `build` 方法用 `PopScope` 包裹 `Scaffold`：
  - `canPop: false` — 禁止默认 pop。
  - `onPopInvokedWithResult` — 优先 `Navigator.pop()`，无法 pop 时 `context.go('/search')`。

### 8. 歌词加载慢和失败

- **根因**：
  1. 无预加载机制——歌词只在用户切到歌词 Tab 时才发起请求。
  2. 串行多请求——LrcLib 最多 3 个串行请求（exact get → 带 artist search → 仅 track_name search），平台端点 1~2 个串行请求，LrcLib 全部跑完才轮到平台端点。
  3. 超时太长——每个请求 connect/send/receive 各 15 秒，最坏 5 个串行请求累计可达 75 秒。
  4. 异常被静默吞掉——`_loadOnlineLyric` 用 `on Object` 捕获所有异常返回 null，UI 显示空状态而非错误态。
- **修复**：
  - `lib/features/player/data/independent_lyric_service.dart`：LrcLib 和平台端点**并行发起**（原来串行），用 `_firstContent` 取首个有效结果。
  - `lib/features/player/data/lrclib_lyric_service.dart`：LrcLib 内部 3 个请求（exact get + 两种 search）**并行发起**（原来串行）。
  - `lib/features/player/state/lyric_controller.dart`：歌词服务专用 Dio，超时从 15 秒缩短到 8 秒。
  - **效果**：原来最坏 5 个串行请求 × 15 秒 = 75 秒；现在并行后最坏只需 1 轮 × 8 秒 = 8 秒。

### 9. 播放页封面兜底补全

- **背景**：部分在线歌曲解析阶段未拿到封面（如酷我搜索结果缺 `web_albumpic_short`、咪咕根相对路径等），进入播放页时封面为空。
- **修复**：
  - 新增 `lib/features/player/data/track_artwork_resolver.dart`：`TrackArtworkResolver` 通过各音源的 `searchTracks` 接口搜索 `title + artist`，取第一个有封面的结果。覆盖全部 5 个在线音源（kw/kg/tx/wy/mg）。
  - `lib/domain/music.dart`：给 `Track` 添加 `copyWith({Uri? coverUri})` 方法。
  - `lib/features/player/state/player_controller.dart`：
    - 注入 `trackArtworkResolverProvider`。
    - `playTrack` 成功加载后异步调用 `_resolveArtwork`。
    - `_resolveArtwork` 检测 `track.coverUri == null` 时调用 resolver，补全后通过 `state.copyWith(track: track.copyWith(coverUri: cover))` 回写。
    - 请求隔离机制（`_playRequest`）确保切换歌曲后不会用旧结果覆盖。
    - 失败时静默处理，不阻塞播放流程。

## 验证

- `dart analyze`：所有修改文件无诊断。
- `flutter test`：
  - `test/kugou_playlist_service_test.dart`：通过（更新 `sourceTrackId` 断言为 `hash`）。
  - `test/kugou_search_parser_test.dart`：通过（更新 `track.id` 断言为 `online:kg:128-hash`）。
  - `test/kuwo_playlist_service_test.dart`：通过。
  - `test/migu_playlist_service_test.dart`：通过。
  - `test/independent_lyric_service_test.dart`：通过（适配并行化后的 mock 逻辑）。
  - `test/lrclib_lyric_service_test.dart`：通过。
  - `test/lyric_controller_test.dart`：通过。
  - `test/lyric_timeline_test.dart`：通过。
  - `test/player_controller_test.dart`：19 通过，1 pre-existing 失败（singleLoop resolveCount，与本次修改无关）。

## 涉及文件

| 文件 | 修改内容 |
|------|---------|
| `lib/domain/music.dart` | `Track.copyWith({Uri? coverUri})` |
| `lib/features/song_list/data/kugou_playlist_service.dart` | `_track` 用 hash 作 sourceTrackId，移除 songId |
| `lib/features/song_list/view/song_list_page.dart` | `PopScope` 拦截返回键 |
| `lib/features/song_list/data/kuwo_playlist_service.dart` | `_trackCover` 增加 albumpic 字段 |
| `lib/features/search/data/kuwo_search_parser.dart` | `_cover` 增加 pic/albumpic/albumPic 回退 |
| `lib/features/leaderboard/data/kugou_search_parser.dart` | `_appendTrack` 用 hash 作 sourceTrackId，移除 songId |
| `lib/features/song_list/data/migu_playlist_service.dart` | `_httpsUri` 处理根相对路径 |
| `lib/features/search/view/search_album_detail_page.dart` | `PopScope` 拦截返回键 |
| `lib/features/player/data/independent_lyric_service.dart` | LrcLib 与平台端点并行 |
| `lib/features/player/data/lrclib_lyric_service.dart` | LrcLib 内部 3 请求并行 |
| `lib/features/player/state/lyric_controller.dart` | 歌词专用 Dio，超时 8 秒 |
| `lib/features/player/data/track_artwork_resolver.dart` | 新增：播放页封面兜底补全 |
| `lib/features/player/state/player_controller.dart` | 注入 resolver，playTrack 后触发封面补全 |
| `test/kugou_playlist_service_test.dart` | 断言更新 |
| `test/kugou_search_parser_test.dart` | 断言更新 |
| `test/independent_lyric_service_test.dart` | 适配并行化 mock |
| `test/player_controller_test.dart` | 适配新构造函数参数 |

## 关键经验

- 酷狗所有解析路径（排行榜/歌单/搜索）的 `sourceTrackId` 必须统一用 `hash`，`extra['songId']` 不设置，让 `_legacyMusicInfo` 回退到 `sourceTrackId = hash`。用数字型 `Audioid`/`audio_id` 会导致 JS 脚本取链失败。
- 酷我封面字段名有大小写差异：API 返回 `albumpic`（全小写），部分接口返回 `albumPic`（驼峰），解析时需两者都尝试。
- 咪咕图片可能返回根相对路径（`/data/oss/...`），需补上 host `https://d.musicapp.migu.cn`。
- 同一页面内通过状态切换的"子页面"（如歌单详情/歌单广场）需用 `PopScope` 拦截系统返回键，否则会直接 pop 整个页面。
- 歌词加载的串行多请求是性能杀手，并行化 + 短超时可大幅降低体感等待时间。
