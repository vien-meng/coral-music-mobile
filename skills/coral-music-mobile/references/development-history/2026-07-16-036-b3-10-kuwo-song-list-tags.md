# B3-10 酷我歌单 HTTPS 分类标签

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标、范围、不做内容与依赖

显示并筛选可由 HTTPS 接口读取的酷我歌单分类标签。

依赖 B3-05。不实现桌面端依赖 HTTP 的 `digest=43` 标签、排序、收藏和导入；移动端不能为这些能力降回明文请求。

## 桌面端基线与确认行为

对照 `sdk/kw/songList.js` 的 `getTag`、`getList`。标签 ID 包含分类 ID 和 digest；`digest=10000` 使用 `getTagPlayList`，可直接由 HTTPS 等价端点读取。

## 实施方案、关键接口、数据与平台差异

- 复用 `KuwoPlaylistService`，只增加标签解析和可选 tagId 请求参数。
- 标签按需通过 `FutureProvider` 加载；选择后调用现有 `SongListController.loadPage`，不复制广场状态。

## 验收、风险与恢复入口

- 收口时验证标签解析、切换重载和 HTTPS 真机请求；不支持的 digest 不应出现在可点击列表。

## 当日实施进度

- 已新增可用标签解析、按标签加载与广场横向筛选控件；`digest=43` 等仅 HTTP 桌面路径未展示。
