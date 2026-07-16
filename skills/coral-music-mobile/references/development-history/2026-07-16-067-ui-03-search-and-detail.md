# UI-03 搜索与详情列表高保真重构

- 阶段：高保真 UI 重构 / 第三任务
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-16
- 完成时间：未完成

## 目标与范围

依据设计稿重构搜索页：圆角搜索框、来源/类型标签、热搜排名、热门歌手横向卡片、轻量搜索结果行和分页；同时为歌单/榜单详情建立统一的圆角头图与列表语言（现有歌单页面在同一任务中评估并按最小范围调整）。

保留 `SearchController` 的真实搜索、分页、来源切换、热门词、歌曲点播与加入列表。不会实现虚构的热门歌手接口；没有真实数据时只显示无网络请求的视觉快捷卡。

## 视觉与数据决策

- 搜索图稿的热门搜索来自现有 `KuwoHotSearchService`，第一至第三名用暖色排名强调，其余保持中性。
- 设计稿“推荐歌手”没有现有数据服务，本阶段以用户可点击的搜索建议卡实现（点击后复用已存在的 search submit），避免新建假数据层。
- 搜索来源改为现有真实来源标签，不新增 API。

## 实施与验证

- 预期改动 `lib/features/search/view/search_page.dart`，必要时调整 song-list 页面样式和现有 Widget 测试。
- UI-01/02 的工具链阻塞不影响编写；完成后只先执行 Dart format、diff 和 skill 校验，HOS SDK 恢复后集中分析与测试。

## 实际进展

- 已重写 `lib/features/search/view/search_page.dart`：搜索页使用圆角搜索框、来源标签、真实热搜排名、点击即搜索的歌手建议、真实搜索结果圆角列表、错误卡和原有分页。搜索、点歌、队列替换、来源切换和“加入列表”仍使用原 controller/provider。
- 设计稿没有给出现成热门歌手数据接口；歌手卡不建立假数据源，仅作为固定搜索建议并显式提示点击会发起真实搜索。
- 已通过 Harmony Flutter 自带 Dart format、`git diff --check` 和 skill 校验；HOS SDK 缺失使 `flutter analyze/test` 仍不可运行。本任务保持 `DOING`，等待工具链恢复统一验收。
- 补充验证：`dart analyze lib test` 已在当前 UI 合并状态通过；Widget 和真机视觉验收仍待环境恢复后执行。

## 关联

- 计划：`2026-07-16-064-plan-high-fidelity-ui.md`。
- 前置：UI-01、UI-02；后续：UI-04 播放与歌词。
