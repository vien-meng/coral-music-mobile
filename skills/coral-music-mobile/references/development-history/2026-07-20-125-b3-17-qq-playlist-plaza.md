# B3-17 QQ 音乐歌单广场与详情

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标与范围

在现有酷我歌单广场中加入 QQ 音乐的热门/最新歌单与详情页，歌单曲目复用既有播放、收藏和下载入口。

不做：桌面端依赖 HTTP 的 QQ 歌单关键词搜索、账号歌单、远端收藏同步或版权绕过。

## 桌面端对照与方案

- 对照 `coral-music-desktop/src/renderer-react/services/musicSdk/sdk/tx/songList.js`：`playlist.PlayListPlazaServer/get_playlist_by_tag`、`fcg_ucc_getcdinfo_byids_cp.fcg`、`cdlist.songlist`。
- 将单一酷我服务提升为小型来源服务映射；页面共享现有标签/排序/分页/详情状态，QQ 暂无可安全迁移的搜索或分类标签时显示空标签而非伪造入口。
- 曲目保留 QQ MID、专辑/歌手封面、文件质量和 mediaMid，继续交由已有 User API 取链。

## 预期验证

- QQ 广场、详情解析 fixture；来源切换不会被旧请求覆盖；已有“播放全部”、收藏和下载按钮保持可用。
- 完成 `dart format`、静态检查、聚焦测试和 Android 关键词/详情真机回归后再改为 `DONE`。

关联：`B3-04`、`B3-15`、`B3-05`、功能矩阵“歌单广场”、`P2-04`。

## 实际修改与验证

- `PlaylistCatalogService` 复用原有酷我服务签名，来源映射注册酷我和 QQ；歌单状态保存当前来源，切换来源会递增请求号并重置旧列表、详情、标签和关键词，避免旧请求覆盖新来源。
- 新增 `QqPlaylistService`：HTTPS `musicu.fcg` 获取热门/最新广场，HTTPS `fcg_ucc_getcdinfo_byids_cp.fcg` 获取详情；曲目复用 QQ MID、专辑/歌手封面、时长、质量和 mediaMid 的既有约定。
- 歌单页新增来源菜单；QQ 不显示无效分类标签，关键词搜索输入框明确禁用，不伪装桌面 HTTP 搜索能力。现有详情播放全部、收藏和下载全部没有改写。
- 新增 QQ 广场和详情解析测试；`dart format` 与 `git diff --check` 已通过。Flutter 静态检查/测试、APK 和真机回归受 2026-07-20 SDK 执行授权用量限制阻断，未绕过。
