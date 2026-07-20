# B6-09 WebDAV 多账号管理

- 阶段：Batch 6 / Phase 5
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标、范围与依赖

让用户保存、切换和删除多个自有 WebDAV 连接；账号展示信息与根地址持久化，Authorization 仍只进入系统安全存储。依赖 B6-03 的现有连接、鉴权、浏览与播放实现。

不做项目服务器、账号同步、密码表单、跨设备同步或服务端搜索；不改变 `Track`、Range 播放和下载链路。

## 桌面端基线与方案

对照桌面端 WebDAV 账户管理行为：用户可管理多个个人连接，切换后后续目录请求、播放与下载使用所选账户的授权。移动端复用现有 `WebDavAccount` 领域类型；账户清单只存 id、显示名和 endpoint，Authorization 按账户 id 存在 `flutter_secure_storage`。

## 实施与验证计划

- 扩展 `WebDavCredentials` 保存非敏感账户索引并保持旧的最近账户恢复兼容。
- WebDAV 页增加连接名称、已保存账户选择与删除；切换不重新输入凭据，删除同步移除对应安全凭据。
- 执行格式化、静态检查和现有 WebDAV URI 回归；真实服务端、Range seek 与三端真机继续由 B6-03/B6-04 验收。

## 实际修改、验证与后续

- `WebDavCredentials` 新增非敏感账户索引的 JSON 编解码、保存与删除；索引只包含 id、显示名、endpoint、rootPath，Authorization 仍按 `webdav:<accountId>` 单独保存在系统安全存储。删除当前账户时会选择最近的剩余账户；旧版单账户的“最近账户”会在首次恢复时无损迁移进索引。
- WebDAV 页面新增连接名称、已保存连接的选择器和删除动作；切换账户读取该账户的既有授权，再复用已有 `PROPFIND`、播放与下载流程，未复制或改变取链逻辑。
- 新增最小账户索引回归，确认序列化内容不包含 Authorization。`dart format`、`flutter analyze`、`flutter test test/webdav_credentials_test.dart test/webdav_client_test.dart` 与 `git diff --check` 通过。
- 状态：DONE。真实服务器的 Range seek、过期凭据与三端真机继续属于 B6-03/B6-04 验收，不在账户管理任务中伪标记。
