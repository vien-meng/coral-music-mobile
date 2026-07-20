# B3-20 歌单广场滚动加载更多

- 阶段：Batch 3 / Phase 2
- 状态：DOING
- 负责人：Codex
- 开始时间：2026-07-20

## 目标与范围

移除歌单广场底部上一页/页码/下一页控件，滚动接近列表底部时自动加载下一页并追加到当前网格。来源、排序、标签、搜索和下拉刷新仍从第 1 页重新加载。

复用现有 `SongListController`、`hasNext` 和服务分页，不新增依赖；控制器负责并发保护与跨页去重，页面只负责滚动触发和底部状态。

## 实施与验证

- 2026-07-20：移除底部上一页、页码和下一页控件，改用 `CustomScrollView`/`SliverGrid` 惰性构建；向下滚动且距底部少于 320px 时自动请求下一页。
- 2026-07-20：控制器新增 `loadMore()`，分页结果追加到现有列表，并按 `source + playlist id` 跨页去重；到达末页后不再请求。下拉刷新固定回到第 1 页。
- 2026-07-20：新增 `test/song_list_controller_test.dart`，覆盖请求页序列、跨页重复项和末页停止。
- 2026-07-20：`dart format --output=none --set-exit-if-changed`、针对性 `dart analyze`、`git diff --check` 通过。
- 2026-07-20：Samsung SM-N986U / Android 13 上 `flutter run -d R5CR70B7SMA --debug` 完成 APK 构建、安装和启动，应用首帧正常。
- 2026-07-20：`flutter test test/song_list_controller_test.dart` 首次被工作区外 Flutter SDK 缓存锁权限拦截；提权重试因审批服务返回 503 未执行，待环境恢复后补跑，因此任务保持 `DOING`。
