# B6-04 WebDAV 下载复用

- 阶段：Batch 6 / Phase 5
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标与范围

允许用户把已浏览到的 WebDAV 音频加入现有下载队列，复用原子 `.part`、暂停/Range 继续、取消、离线播放和任务清理能力。

不做：项目服务器、WebDAV 目录批量下载、多账号同步，或将 WebDAV 资源交给 User API/在线音质链。

## 依赖、方案与安全

- 依赖 B6-01 下载状态机、B6-03 WebDAV 目录与安全凭据。
- `PlaybackResolver` 已为 WebDAV 返回仅运行期的 Authorization 请求头；下载器直接复用该解析结果，SQLite 仍只保存 Track 快照、路径、状态和错误摘要。
- 对照桌面端 WebDAV 文件下载行为：保留远程文件扩展名，连接凭据不写入下载记录、日志或文件名。

## 验收

- WebDAV 音频可从目录行加入下载页，下载完成后离线播放。
- 暂停/继续保持 Authorization 仅在当前请求中使用；取消删除临时文件。
- 使用真实带鉴权服务器的下载与 Range 行为留作三端真机验收。

## 实际修改与验证

- `DownloadController.enqueue` 现允许 `TrackSourceKind.webdav`，仍拒绝本地与已下载曲目；WebDAV 的播放解析结果会把仅运行期 Authorization 传给 Dio。
- WebDAV 音频目录行增加“下载到本机”细线图标，点击后进入同一下载页；原始扩展名、`.part`、暂停/续传/取消和离线播放均复用 B6-01。
- `dart format`、`flutter analyze`、`git diff --check` 通过。真实服务器鉴权下载和三端 Range 验收待完成，状态保持 `DOING`。
