# B3-19 搜索发现数据修复

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 范围

修复搜索空态热词持续加载失败，并为固定推荐歌手补真实头像。热门词改用桌面端已有的 QQ MusicU HTTPS 协议；歌手头像复用桌面端 QQ 歌手图片 CDN 规则和应用现有 `CoverImage`，不新增依赖或虚构数据服务。

## 实施与验证

- 删除依赖旧酷我 HTTPS 兼容性的 `KuwoHotSearchService`，改为桌面端已使用的 QQ MusicU `GetHotkeyForQQMusicPC` HTTPS 请求；provider 继续保留首次加载和失效重试语义。
- 新解析器校验根响应与 `hotkey.data.vec_hotkey`，清理空白、去重并限制 20 条；`test/hot_search_service_test.dart` 覆盖正常、重复、空项与异常响应。
- 搜索发现区提取为 `search_discovery.dart`，`search_page.dart` 从 576 行降至 390 行。四位固定推荐歌手使用 QQ 歌手 MID 的 HTTPS 头像，加载失败保留原渐变兜底。
- 本次改动文件 `dart analyze` 无问题，`git diff --check` 通过。外部网络与 Flutter SDK 缓存授权服务均不可用，真实 HTTPS 响应和 `flutter test` 待环境恢复后执行，状态保持 `DOING`。
