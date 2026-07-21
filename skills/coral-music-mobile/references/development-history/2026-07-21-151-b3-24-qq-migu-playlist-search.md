# B3-24 QQ 与咪咕歌单关键词搜索

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 目标与边界

移除歌单广场中 QQ、咪咕“关键词搜索暂未接入”的占位状态，接入桌面端已有的歌单搜索协议，复用 `PlaylistCatalogService`、现有分页状态和列表详情入口。

- QQ 仅使用同域 HTTPS 端点，不启用桌面旧 HTTP 请求。
- 咪咕复用现有 HTTPS 搜索签名规则，不引入账号、服务端代理或新的依赖。
- 搜索结果继续归一化为 `OnlinePlaylist`，不改变收藏、播放和下载路径。

## 验证要求

- QQ、咪咕服务验证空关键词与非法页码，并返回归一化分页结果。
- 两个来源的搜索框可输入并提交。
- 解析测试覆盖名称、封面、作者、数量与分页。

## 实施与验证

- `QqPlaylistService` 使用桌面端同一 `client_music_search_songlist` 协议，但通过 `c.y.qq.com` HTTPS 请求；结果解析为现有 `OnlinePlaylist`。
- `MiguPlaylistService` 使用桌面端 `songlist` 搜索开关和现有歌曲搜索同一 MD5 签名规则；没有新增依赖、账号或服务端代理。
- 歌单广场的搜索框不再按来源禁用，继续调用已有 `SongListController.submitSearch()` 与分页加载逻辑。
- QQ、咪咕解析测试覆盖搜索结果，`dart format`、定向 `dart analyze` 与 `git diff --check` 已通过。
- 在线冒烟和 `flutter test` 待执行：沙箱 DNS 无法解析公开 QQ 域名；申请工作区外 Flutter SDK/网络访问后外部审批服务返回 HTTP 503，未绕过。任务保持 `DOING`。
