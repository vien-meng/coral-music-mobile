# B6-15 不感兴趣关键词规则

- 阶段：Batch 6 / Phase 6
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-20
- 完成时间：2026-07-20

## 目标、范围与依赖

在已有单曲不感兴趣规则之外，支持用户维护不区分大小写的关键词；当排行榜、歌单、列表或分类执行“播放全部”时，标题、歌手或专辑命中关键词的歌曲不进入新队列。

依赖 B6-13 的建队前过滤点。不会影响手动点播、当前播放队列或播放器完成/报错路径，不做模糊拼音、在线服务端过滤或自动删除。

## 实施记录

- 2026-07-20：开始增加 SQLite v8 关键词表和规则管理 UI。
- SQLite schema 升级至 v8，新增 `ignored_keyword` 表；关键词保存时去空格、小写化、限制 1–80 字符，并由数据库主键去重。
- `filterIgnored` 仍只由现有“播放全部”入口调用，现同时过滤单曲 ID 与关键词；手动点播和播放器自动切歌不受影响。
- 不感兴趣页支持添加、删除、清空关键词，并保留单曲恢复入口；资料备份同步纳入关键词规则。
- 实际修改：`library_store.dart`、`library_backup_codec.dart`、`ignored_tracks_page.dart`、`test/ignored_keyword_test.dart`。
- 验证：`dart format`、`flutter analyze`、`flutter test test/ignored_keyword_test.dart test/library_backup_codec_test.dart test/playlist_transfer_codec_test.dart test/playlist_duplicates_test.dart`、`git diff --check` 通过。

## 已知限制与下一步

- 关键词采用直接包含匹配，不做拼音/同义词/正则表达式，以避免误过滤与规则解释困难。
- 下一步：只加入有真实持久化行为的主题/语言等设置项。
