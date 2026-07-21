# B4-40 QQ/咪咕播放与独立歌词兜底

- 阶段：Batch 4 / Phase 3
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-21

## 根因与目标

移动端向 User API 传递的曲目信息只保留了新结构的 `meta`，没有完整复刻桌面脚本读取的顶层旧字段。QQ 取链依赖 `strMediaMid`、`types/_types`，咪咕取链依赖 `copyrightId` 及歌词 URL；因此两源可搜索但无法播放。

歌词服务统一按歌名和歌手调用独立 LrcLib 搜索，不调用 User API、音源脚本、来源接口或原生歌词通道。

## 实施与验证

- `MethodChannelUserApiRunner` 现在同时传递桌面脚本使用的顶层 `img`、`typeUrl`、`types/_types`、`strMediaMid`、`copyrightId`、`lrcUrl/mrcUrl/trcUrl`，保留已有 `meta` 结构；QQ、咪咕可以按桌面协议取链。
- 咪咕搜索、榜单和歌单详情保存 MRC/LRC/TRC 链接，来源歌词优先读取 MRC；来源接口空结果或异常后继续由 LrcLib 搜索。LrcLib 精确查询错误不再阻断关键词查询，先以歌名加歌手查询，未命中再仅以歌名查询，并在候选中按标题和歌手相似度选择最接近项。
- 新增 QQ/咪咕 User API 协议字段、咪咕歌词 URL、LrcLib 精确查询失败转关键词搜索、歌名回退和最近候选选择的回归用例。`dart format`、定向 `dart analyze`、`git diff --check` 已通过。
- 2026-07-21 已在 SM-N986U 构建、安装并启动 Debug APK，无启动崩溃。`flutter test` 仍受工作区外 SDK 缓存审批服务 HTTP 503 阻断，QQ/咪咕实际取链和歌词需在已安装真机中手动确认，任务保持 `DOING`。
- 歌单详情响应增加 JSON/JSONP 文本归一化，覆盖 QQ、酷我和咪咕服务端的响应格式差异；咪咕补齐 `ZQ24` 与各档文件大小，避免 User API 选择默认无损时缺少可用格式。歌词主链为“本地 LRC → IndependentLyricService 的公开平台端点 → LrcLib → 会话缓存”，并删除 User API manifest 的歌词能力、Dart/Android 歌词调用；聚合器不读取当前音源脚本。
