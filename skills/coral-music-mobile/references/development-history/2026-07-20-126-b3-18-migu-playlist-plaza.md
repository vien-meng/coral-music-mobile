# B3-18 咪咕音乐歌单广场与详情

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标与范围

接入咪咕 HTTPS 推荐歌单、标签和详情曲目，并纳入已有歌单来源切换、播放、收藏和下载流程。

不做：另起一套歌单关键词签名搜索、来源账号能力或服务器数据同步。

## 桌面端对照与方案

- 对照 `coral-music-desktop/src/renderer-react/services/musicSdk/sdk/mg/songList.js`：推荐广场、标签、歌单信息和歌曲列表均为 `app.c.nf.migu.cn/c.musicapp.migu.cn` HTTPS 端点。
- 复用现有 `PlaylistCatalogService`、咪咕歌曲的 `PQ/HQ/SQ/ZQ` 质量映射和既有 User API 取链字段，避免引入新的状态管理或网络依赖。
- 无可安全复用的歌单关键词搜索时在 UI 明确禁用；只交付真实可访问的广场、标签和详情。

## 预期验证

- 递归广场响应、标签、详情歌曲和质量 fixture；来源切换/分页不被旧响应覆盖。
- 完成格式、静态检查、聚焦测试及 Android 真机广场→详情→播放回归后改为 `DONE`。

关联：`B3-07`、`B3-13`、`B3-17`、功能矩阵“歌单广场”、`P2-04`。

## 实际修改与验证

- 新增 `MiguPlaylistService`：读取推荐/按标签广场、递归收集嵌套 `2021` 歌单，兼容旧 `contentItemList` 响应结构；响应未给出总数时只在满页时开放下一页，避免无界分页。
- 迁移咪咕标签、歌单元信息和首个详情页歌曲；歌曲沿用 `PQ/HQ/SQ/ZQ` 到 `128k/320k/FLAC/FLAC 24bit` 的既有质量映射，以及 album/copyright 字段。
- 来源菜单加入咪咕；仅酷我保留真实歌单关键词搜索，QQ/咪咕均明确禁用无安全实现的输入入口。
- 新增咪咕标签、广场和详情解析测试；`dart format` 与 `git diff --check` 已通过。Flutter 静态检查、测试、APK 和真机回归继续受当前 SDK 执行授权用量限制阻断。
