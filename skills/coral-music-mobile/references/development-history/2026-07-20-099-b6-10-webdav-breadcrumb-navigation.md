# B6-10 WebDAV 面包屑导航

- 阶段：Batch 6 / Phase 5
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：未完成

## 目标、范围与依赖

为已连接 WebDAV 的当前目录提供可点击面包屑，用户可直接返回任一已配置根目录内的祖先目录。依赖 B6-03、B6-05 的目录浏览与根目录边界校验。

不做服务端全文搜索、跨根目录跳转或账户同步；面包屑只重用本地已知 URI 和既有 `PROPFIND` 浏览。

## 桌面端行为与实施

桌面端文件浏览器以当前根目录为边界显示路径层级。移动端新增纯 URI 辅助函数，协议、主机、端口不一致或超出根路径时只返回根项；页面上的祖先项直接调用现有 `_browse`。

## 实际修改、验证与后续

- `webDavBreadcrumbs` 将已配置根目录到当前目录转为 URI 层级；异源或根外路径只返回根目录，不允许 UI 构造越界请求。
- WebDAV 目录顶部显示紧凑的可点击面包屑，当前项不可点击，祖先项直接复用既有 `_browse` 和授权读取；原有“返回上级”快捷操作保留。
- `dart format`、`flutter analyze`、`flutter test test/webdav_client_test.dart test/webdav_credentials_test.dart` 和 `git diff --check` 通过。
- 状态：DONE。真实服务端 Range、鉴权过期和三端真机回归仍属于 WebDAV 播放/下载验收。
