# B3-16 酷狗音乐歌曲搜索

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标与范围

使用桌面端已经验证的 HTTPS 搜索端点接入酷狗单源与综合歌曲搜索，保留其 `hash`、各音质对应 hash 和大小，供既有 User API 取链使用。

不做：不可用的酷狗 HTTP 榜单、封面二次查询、歌单/评论接口，或绕过来源版权与地区限制。

## 桌面端对照与方案

- 对照 `coral-music-desktop/src/renderer-react/services/musicSdk/sdk/kg/musicSearch.js`：`songsearch.kugou.com/song_search_v2`、`data.lists`、`Grp`、`FileHash/HQFileHash/SQFileHash/ResFileHash`。
- 复用已有 `OnlineCatalogService`、Dio、`SearchController`、分页与错误隔离；新服务只声明搜索能力，榜单继续返回明确的不支持错误。
- 将每档 hash/size 放入 `Track.extra`，并由既有 User API 的旧协议适配层原样传给脚本；不新增平台通道或网络依赖。

## 实施与验证

- 新增 `KugouCatalogService` 和 `KugouSearchParser`：请求 `song_search_v2`、展开 `Grp`、稳定去重并归一化歌曲、歌手、专辑、时长与 `128k/320k/FLAC/FLAC 24bit`。
- 若搜索响应提供 `Image/AlbumImage`，将其尺寸模板固定为 480 并升级为 HTTPS，供现有列表、迷你播放器和播放详情复用；没有该字段则保持无封面，不进行旧 HTTP 封面二次查询。
- 注册到多来源目录服务，搜索页可选择“酷狗音乐”，综合搜索同时请求酷我、酷狗、QQ、网易云和咪咕；单源失败维持已有隔离语义。
- `Track.extra.qualityMeta` 保存每档 hash/size；`MethodChannelUserApiRunner` 现在会把它写入桌面兼容 `qualitys/_qualitys`，使酷狗脚本能按所选质量取链。
- 新增酷狗 fixture 解析断言，并扩展已有综合搜索/音源协议测试。`dart format` 与 `git diff --check` 已通过。
- `flutter analyze`、`flutter test`、Debug APK 和真机关键词搜索待补：2026-07-20 Flutter SDK 缓存执行授权被环境用量限制拒绝，未以其它方式绕过该限制。

## 风险与恢复入口

- 该公共搜索端点和 User API 脚本均可能受服务端策略影响；失败应映射为单来源错误，不得覆盖其它综合搜索结果。
- 恢复入口：`lib/features/leaderboard/data/` 的酷狗服务和搜索页来源菜单。

关联：`development-history/2026-07-20-123-b3-15-qq-music-search.md`、功能矩阵“搜索”、`P2-03`。
