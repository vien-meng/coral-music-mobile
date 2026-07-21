# UI-20 在线封面加载与播放队列

- 阶段：高保真 UI / 播放器
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 根因与目标

排行榜、搜索和歌单详情各自使用裸 `Image.network`，没有沿用已有的封面组件。来源接口请求带浏览器 User-Agent，而图片 CDN 请求没有，切换来源后常被图片服务拒绝并落入空占位。播放队列使用默认列表样式，封面、当前播放态和操作层级不清晰。

所有在线封面应通过一个组件加载，使用同一请求头、HTTPS 归一化、尺寸约束和失败占位。队列保留下载、删除、拖拽和切歌行为，仅提升信息层级与当前曲目状态。

## 验证要求

- 有效 HTTP/HTTPS 封面均通过统一组件加载；不支持的 URL 回退占位而不抛异常。
- 排行榜、搜索、歌单详情和播放队列不再直接使用裸网络图片。
- 队列当前曲目、封面、标题、歌手和操作在窄屏可辨识。

## 实施与验证

- `CoverImage` 为远程封面统一使用浏览器 User-Agent，并将 HTTP/协议相对图片地址归一为 HTTPS；文件封面仍走 `Image.file`，无效 URI 与网络失败继续回退调用方占位。
- 排行榜、搜索和歌单详情移除各自的裸 `Image.network`，统一复用 `CoverImage`。播放队列已有同一组件，现在也受益于相同请求头和地址归一化。
- 播放队列改为带循环模式的紧凑头部、52px 封面、当前播放标识、来源信息和轻量选中背景；下载、移除、拖拽排序和点歌行为保持不变。
- `test/cover_image_test.dart` 覆盖 HTTP 地址升级为 HTTPS 及 CDN 请求头。
- `dart format`、定向 `dart analyze` 和 `git diff --check` 通过。
- Flutter 测试未运行：工作区外 Flutter SDK 缓存锁的审批服务返回 HTTP 503。待服务恢复后运行 `flutter test test/cover_image_test.dart` 并在 Android 真机切换酷我、QQ、咪咕、网易云后检查榜单、搜索、歌单和队列封面，任务保持 `DOING`。

## 2026-07-21 真机反馈修订

- SM-N986U 已确认 QQ 音乐和网易云音乐可真实播放，封面仍为空，说明通用 User-Agent 不足以满足这些 CDN 的防盗链规则。
- `CoverImage` 根据 CDN 主机补齐 QQ、网易云、酷我、咪咕和酷狗的 Referer，同时保留统一 User-Agent、Accept、HTTPS 归一化和失败占位。
- 首页来源菜单补入酷狗；首页、搜索和歌单广场均按当前已启用 User API 的 `musicUrlSources` 过滤平台。搜索的“综合搜索”仅在当前音源支持全部搜索来源时显示，避免返回无法播放的歌曲。
- `test/cover_image_test.dart` 增加 QQ/网易云 Referer 检查，`test/online_source_menu_test.dart` 增加音源能力过滤检查；定向 `dart analyze`、格式和差异检查通过。
- 本轮 `flutter run --release` 未返回安装完成回执，且 Release APK 时间戳未更新；不作为真机覆盖安装证据。待构建环境稳定后重新构建并在该设备复测封面与菜单。
