# B6-05 WebDAV 目录浏览与搜索

- 阶段：Batch 6 / Phase 5
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标与范围

在既有 WebDAV 连接、目录读取、播放和下载基础上，补当前目录内搜索与返回上级目录；所有导航继续复用同一账号授权和 `PROPFIND` 请求。

不做：服务端全文搜索、账户同步、项目托管存储或明文凭据持久化。

## 依赖与验证

- 依赖 B6-03 WebDAV 连接和 B6-04 下载复用。
- 完成后执行格式、静态检查与现有 WebDAV 解析测试；真实服务端 Range/鉴权验收仍保留三端真机阶段。

## 实际修改

- 已实现当前目录本地关键词筛选；不发送服务端搜索请求，也不改变现有 WebDAV 请求协议。
- 已实现上级导航，纯 URI 逻辑拒绝跨协议、主机、端口或已配置根目录向上跳转；根目录不显示返回按钮。
- 新增最小 URI 回归测试，`flutter analyze`、`flutter test test/webdav_client_test.dart test/local_audio_scanner_test.dart` 和 `git diff --check` 通过。
- 状态：DONE（真实服务端 Range seek、鉴权过期与三端真机仍由 B6-03/B6-04 验收，不在本 UI/导航任务中伪标记）。
