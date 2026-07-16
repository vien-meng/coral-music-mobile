# B3-01 迁移酷我歌曲搜索

- 阶段：Batch 3
- 状态：DONE
- 负责人：Codex
- 开始时间：2026-07-15
- 完成时间：2026-07-15

## 目标与范围

迁移桌面端酷我歌曲搜索，使用 HTTPS 搜索端点、共享歌曲归一化和分页结果。依赖 B1-04、B1-05、B2-02；不实现综合搜索、歌单搜索、历史或热门词。

## 桌面端基线与决策

对照 `src/renderer-react/services/musicSdk/sdk/kw/musicSearch.js`。桌面使用 HTTP 地址；已验证同一端点的 HTTPS 可返回 JSON，因此移动端只使用 HTTPS，避免 iOS 明文网络例外。

## 实施、接口与数据变更

- 扩展 `OnlineCatalogService.searchTracks(source, query, page)`；没有提前增加综合、歌单或历史搜索接口。
- `KuwoCatalogService` 使用桌面同等请求参数访问 `https://search.kuwo.cn/r.s`，每页 30 首；响应按文本读取并 `jsonDecode`，避免远端 JSON Content-Type 不稳定造成 Dio 自动转换失败。
- 新增 `KuwoSearchParser`，将 `MUSICRID` 归一为源歌曲 ID，清理 HTML 实体和歌手分隔符，去除重复 ID，并共享酷我音质解析。
- 将榜单解析器的文本与音质辅助方法公开为同一来源的稳定复用点，未引入通用解析框架。

## 实际修改文件与完成内容

- `lib/features/leaderboard/data/online_catalog_service.dart`：增加歌曲搜索契约。
- `lib/features/leaderboard/data/kuwo_catalog_service.dart`：实现 HTTPS 搜索、错误映射和文本 JSON 解码。
- `lib/features/leaderboard/data/kuwo_leaderboard_parser.dart`：公开同源文本/音质归一化方法。
- `lib/features/search/data/kuwo_search_parser.dart`：新增搜索响应归一化。
- `test/fixtures/kuwo_search.json`、`test/kuwo_search_parser_test.dart`：固定响应契约、重复 ID 与音质验证。
- `test/kuwo_search_live_smoke_test.dart`：仅在 `CORAL_LIVE_TEST=true` 时运行的 HTTPS 冒烟。
- `test/support/fake_catalog_service.dart`、`test/leaderboard_controller_test.dart`：补齐扩展接口实现。

## 重要决策与调整

桌面端采用 HTTP；移动端经实际请求确认 HTTPS 等价可用，固定为 HTTPS 以满足 iOS ATS。首次用 Dio 的 Map 泛型读取实时响应失败；根因是端点返回 JSON 文本，改为 `ResponseType.plain` 后显式解码，实时测试通过。

## 验证

- `dart format lib test`：通过。
- `flutter analyze`：通过，无问题。
- `flutter test`：通过；两个在线冒烟默认跳过。
- `flutter test test/kuwo_search_live_smoke_test.dart --dart-define=CORAL_LIVE_TEST=true`：通过，返回非空的规范化歌曲。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 真机：未执行；本任务不涉及平台媒体能力。

## 风险、阻塞与后续

远端响应字段仍可能变化，固定 fixture 覆盖缺失字段和重复 ID，发布前需重跑可选实时冒烟。关联 B3-02、P2-03。
