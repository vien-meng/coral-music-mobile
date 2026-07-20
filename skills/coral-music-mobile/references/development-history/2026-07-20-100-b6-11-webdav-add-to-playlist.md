# B6-11 WebDAV 加入我的列表

- 阶段：Batch 6 / Phase 5
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标、范围与依赖

让 WebDAV 音频可加入既有“我的列表”，以便和在线、本地、下载曲目共用持久化列表与队列能力。依赖 B5 列表 CRUD 与 B6-03 的 WebDAV `Track` 归一化。

不复制列表选择器、不新建远端同步或缓存；WebDAV 授权继续只在运行时由既有 resolver 安全读取。

## 实际修改、验证与后续

- WebDAV 音频行新增“添加到我的列表”，直接复用在线歌单/搜索已使用的 `addTrackToPlaylist` 选择器与 SQLite 去重。
- 保存的 `Track` 仍带 `webdav` sourceKind、账户 id 与远端 URI；再次播放时现有 resolver 从安全存储读取对应 Authorization，不会落库凭据或进入 User API。
- `dart format`、`flutter analyze`、`flutter test test/webdav_client_test.dart test/webdav_credentials_test.dart` 和 `git diff --check` 通过。
- 状态：DONE。真实服务端 Range seek 和跨重启授权回归继续属于 B6-03/B6-04。
