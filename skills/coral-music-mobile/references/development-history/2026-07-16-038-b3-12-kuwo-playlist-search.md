# B3-12 酷我歌单搜索

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

在歌单广场搜索酷我歌单，复用现有详情、播放和分页路径。依赖 B3-05；不实现跨来源歌单搜索、搜索历史和收藏。

## 桌面端基线与实施

对照 `sdk/kw/songList.js` 的 `search`，使用 HTTPS `search.kuwo.cn/r.s` 与 `ft=playlist`。搜索状态保存在既有 `SongListState`；关键词为空时回到当前标签/排序广场。

## 验收与恢复入口

- 收口时验证关键词、分页、清空恢复广场和详情播放。
- 恢复入口：`kuwo_playlist_service.dart`、`song_list_controller.dart`、`song_list_page.dart`。

## 当日实施进度

- 已接入 HTTPS 歌单搜索、结果解析、分页和广场搜索输入；提交空关键词会恢复当前标签与排序的广场请求。
