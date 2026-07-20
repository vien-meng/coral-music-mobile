# B6-03 WebDAV 远程媒体基础

- 阶段：Batch 6 / Phase 5
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标与边界

实现用户自有 WebDAV 的连接、目录浏览、音频过滤、带鉴权 Range 播放和下载复用；不建设任何项目服务器或跨设备同步。

## 安全约束

账号密码或 Token 只能保存到系统安全存储，SQLite 仅可保存账号标识和非敏感目录/展示信息；日志不输出 Authorization、URL 用户信息或密码。

## 实际修改与验证

- 新增 WebDAV `PROPFIND` 目录客户端、响应条目、音频格式识别、统一 Track 转换和 Range 请求选项。
- endpoint 拒绝内嵌用户信息；授权仅由 `flutter_secure_storage` 的 `WebDavCredentials` 保存与读取，并通过 Riverpod 提供。
- WebDAV 页面现已支持验证连接后直接浏览目录、刷新、进入子目录和筛选可播放音频；点击音频会以当前目录中的音频构建既有播放队列。
- `ResolvedPlaybackUrl` 与 `AudioEngine` 增加仅运行期的请求头传递，WebDAV 播放使用安全存储中读取的 Authorization 交给 `just_audio`；URL、音源脚本和 Authorization 不进入 SQLite 或日志。
- `flutter analyze` 与 `git diff --check` 通过。真实服务器的 PROPFIND/XML 差异、带鉴权 Range seek、下载复用及 iOS/鸿蒙真机验收待继续，任务保持 `DOING`。
